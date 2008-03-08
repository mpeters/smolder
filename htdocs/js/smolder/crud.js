// CRUD abstraction for Smolder
Smolder.__known_CRUDS = { };
Smolder.CRUD = Class.create();

/* Class methods */
Smolder.CRUD.exists   = function(id)   { return Smolder.__known_CRUDS[id] ? true : false; };
Smolder.CRUD.find     = function(id)   { return Smolder.__known_CRUDS[id] };
Smolder.CRUD.remember = function(crud) { Smolder.__known_CRUDS[crud.div.id] = crud; };
Smolder.CRUD.forget   = function(crud) { Smolder.__known_CRUDS[crud.div.id] = false; };

/* Object methods */
Object.extend(Smolder.CRUD.prototype, {
    initialize: function(id, url) {
        this.div      = $(id);
        this.url      = url;
        this.list_url = url + '/list?table_only=1';

        // initialize these if we don't already have a crud
        this.add_shown = false;
        // find the containers, triggers and indicator that won't change
        this.list_container = this.div.select('.list_container')[0];
        this.add_container  = this.div.select('.add_container')[0];
        this.indicator      = this.div.select('.indicator')[0].id;
        this.add_trigger    = this.div.select('.add_trigger')[0];
        // add the handlers for the triggers
        this.add_trigger.onclick = function() {
            this.toggle_add();
            // prevent submission of the link
            return false;
        }.bindAsEventListener(this);

        // find our triggers that might change (edit and delete)
        this.refresh();

        // the fact that we've created this CRUD
        Smolder.CRUD.remember(this);
    },
    refresh: function() {
        this.edit_triggers   = $(this.list_container).select('.edit_trigger');
        this.delete_triggers = $(this.list_container).select('.delete_trigger');

        this.edit_triggers.each( 
            function(trigger) {
                trigger.onclick = function() {
                    this.show_edit(trigger);
                    // prevent submission of the link
                    return false;
                }.bindAsEventListener(this);
            }.bindAsEventListener(this)
        );

        this.delete_triggers.each(
            function(trigger) {
                trigger.onclick = function() {
                    this.show_delete(trigger);
                    // prevent submission of the link
                    return false;
                }.bindAsEventListener(this);
            }.bindAsEventListener(this)
        );
    },
    toggle_add: function() {
        if( this.add_shown ) {
            this.hide_add();
        } else {
            this.show_add();
        }
    },
    hide_add: function() {
        new Effect.SlideUp(this.add_container);
        this.add_shown  = false;
    },
    show_add: function() {
        Smolder.Ajax.update({
            url        : this.add_trigger.href,
            target     : this.add_container.id,
            indicator  : this.indicator,
            onComplete : function(args) {
                if( !this.add_shown ) {
                    new Effect.SlideDown(this.add_container)
                }
                this.add_shown  = true;

                // make sure we submit the add changes correctly
                this._handle_form_submit('add_form');

            }.bindAsEventListener(this)
        });
    },
    _handle_form_submit: function(name) {
        var form = $(this.add_container).select('.' + name)[0];
        if( form ) {
            form.onsubmit = function() {
                this.submit_change(form);
                return false;
            }.bindAsEventListener(this);
        }
    },
    show_edit: function(trigger) {
        var matches = trigger.className.match(/(^|\s)for_item_(\d+)($|\s)/);
        var itemId  = matches[2];
        if( itemId == null ) 
            return;

        Smolder.Ajax.update({
            url        : trigger.href,
            target     : this.add_container.id,
            indicator  : this.indicator,
            onComplete : function() {
                if( !this.add_shown ) {
                    Effect.SlideDown(this.add_container);
                }
                this.add_shown = true;

                // setup the 'cancel' button
                var cancel = $(this.add_container).select('.edit_cancel')[0];
                cancel.onclick = function() { this.hide_add(); }.bindAsEventListener(this);

                // make sure we submit the add changes correctly
                this._handle_form_submit('edit_form');

            }.bindAsEventListener(this)
        });
    },
    show_delete: function(trigger) {
        var matches = trigger.className.match(/(^|\s)for_item_(\d+)($|\s)/);
        var itemId  = matches[2];

        // set the onsubmit handler for the form in this popup
        var form = $('delete_form_' + itemId);
        form.onsubmit = function() {
            Smolder.Ajax.update({
                url        : form.action,
                target     : this.list_container.id,
                indicator  : 'delete_indicator_' + itemId,
                onComplete : function() {
                    this.refresh();
                }.bindAsEventListener(this)
            });
            return false;
        }.bindAsEventListener(this);
        
        // show the popup form
        var popup = 'delete_' + itemId;
        Smolder.togglePopupForm(popup);
    },
    submit_change: function(form) {

        // find the add_inidicator
        var indicator = $(this.add_container).select('.add_indicator')[0].id;
        Smolder.Ajax.form_update({
            form       : form,
            target     : this.add_container.id,
            indicator  : indicator,
            onComplete : function(args) {
                // if the submission changed the list
                if( args.json.list_changed ) {
                    this.add_shown = false;
                    Element.hide(this.add_container);
                    this.update_list();
                }

                // since the add/edit forms may exist still
                // (ie, their submission was incorrect so it reappears with error msgs)
                // we need to make sure they're submitted correctly the 2nd time
                this._handle_form_submit('add_form');
                this._handle_form_submit('edit_form');
        
            }.bindAsEventListener(this)
        });
    },
    update_list: function () {
        Smolder.Ajax.update({
            url       : this.list_url,
            target    : this.list_container.id,
            indicator : this.indicator,
            onComplete: function () {
                // refresh this CRUD since we know have new content
                this.refresh();
            }.bindAsEventListener(this)
        });
    }
});
