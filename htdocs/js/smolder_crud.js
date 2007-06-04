// CRUD abstraction for Smolder
var __known_CRUDS = { };
CRUD = Class.create();

/* Class methods */
CRUD.exists   = function(id)   { return __known_CRUDS[id] ? true : false; };
CRUD.find     = function(id)   { return __known_CRUDS[id] };
CRUD.remember = function(crud) { __known_CRUDS[crud.div.id] = crud; };
CRUD.forget   = function(crud) { __known_CRUDS[crud.div.id] = false; };

/* Object methods */
Object.extend(CRUD.prototype, {
    initialize: function(id, url) {
        this.div      = $(id);
        this.url      = url;
        this.list_url = url + '/list?table_only=1';

        // initialize these if we don't already have a crud
        this.add_shown = false;
        // find the containers, triggers and indicator that won't change
        this.list_container = document.getElementsByClassName('list_container', this.div)[0];
        this.add_container  = document.getElementsByClassName('add_container', this.div)[0];
        this.indicator      = document.getElementsByClassName('indicator', this.div)[0].id;
        this.add_trigger    = document.getElementsByClassName('add_trigger', this.div)[0];
        // add the handlers for the triggers
        this.add_trigger.onclick = function() {
            this.toggle_add();
            // prevent submission of the link
            return false;
        }.bindAsEventListener(this);

        // find our triggers that might change (edit and delete)
        this.refresh();

        // the fact that we've created this CRUD
        CRUD.remember(this);
    },
    refresh: function() {
        this.edit_triggers   = document.getElementsByClassName('edit_trigger', this.list_container);
        this.delete_triggers = document.getElementsByClassName('delete_trigger', this.list_container);

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
        ajax_submit({
            url        : this.add_trigger.href,
            div        : this.add_container.id,
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
        var form = document.getElementsByClassName(name, this.add_container)[0];
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

        ajax_submit({
            url        : trigger.href,
            div        : this.add_container.id,
            indicator  : this.indicator,
            onComplete : function() {
                if( !this.add_shown ) {
                    Effect.SlideDown(this.add_container);
                }
                this.add_shown = true;

                // setup the 'cancel' button
                var cancel = document.getElementsByClassName('edit_cancel', this.add_container)[0];
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
            ajax_submit({
                url: form.action,
                div: this.list_container.id,
                indicator: 'delete_indicator_' + itemId,
                onComplete : function() {
                    this.refresh();
                }.bindAsEventListener(this)
            });
            return false;
        }.bindAsEventListener(this);
        
        // show the popup form
        var popup = 'delete_' + itemId;
        togglePopupForm(popup);
    },
    submit_change: function(form) {

        // find the add_inidicator
        var indicator = document.getElementsByClassName('add_indicator', this.add_container)[0].id;
        ajax_form_submit({
            form       : form,
            div        : this.add_container.id,
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
        ajax_submit({
            url       : this.list_url,
            div       : this.list_container.id,
            indicator : this.indicator,
            onComplete: function () {
                // refresh this CRUD since we know have new content
                this.refresh();
            }.bindAsEventListener(this)
        });
    }
});
