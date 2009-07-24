var Smolder = {};

Smolder.load = function(target, json) {
    if(! json) json = {};
    // update the navigation if we need to
    if( json.update_nav ) Smolder.update_nav();

    // apply our registered behaviours
    Behaviour.apply(target);

    // run any code from Smolder.onload()
    var size = Smolder.onload_code.length;
    for(var i=0; i< size; i++) {
        var code = Smolder.onload_code.pop();
        if( code ) code();
    }

    // show any messages we got
    Smolder.show_messages(json);
};

/*
    Smolder.onload()
    Add some code that will get executed after the DOM is loaded
    (but without having to wait on images, etc to load).
    Multiple calls will not overwrite previous calls and all code
    given will be executed in the order give.
*/
Smolder.onload_code = [];
Smolder.onload = function(code) {
    Smolder.onload_code.push(code);
};

/*
    Smolder.Cookie.get(name)
    Returns the value of a specific cookie.
*/
Smolder.Cookie = {};
Smolder.Cookie.get = function(name) {
    var value  = null;
    var cookie = document.cookie;
    var start, end;

    if ( cookie.length > 0 ) {
        start = cookie.indexOf( name + '=' );

        // if the cookie exists
        if ( start != -1 )  {
          start += name.length + 1; // need to account for the '='

          // set index of beginning of value
          end = cookie.indexOf( ';', start );

          if ( end == -1 ) end = cookie.length;

          value = unescape( cookie.substring( start, end ) );
        }
    }
    return value;
};

/*
    Smolder.Cookie.set(name, value)
    Sets a cookie to a particular value.
*/
Smolder.Cookie.set = function(name, value) {
    document.cookie = name + '=' + value;
};

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.update_nav = function(){
    Smolder.Ajax.update({
        url    : '/app/public/nav',
        target : 'nav'
    });
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// FUNCTION: Smolder.Ajax.request
// takes the following named args
// url       : the full url of the request (required)
// parmas    : an object of query params to send along
// indicator : the id of the image to use as an indicator (optional defaults to 'indicator')
// onComplete: a call back function to be executed after the normal processing (optional)
//              Receives as arguments, the same args passed into Smolder.Ajax.request
//
//  Smolder.Ajax.request({
//      url        : '/app/some_mod/something',
//      params     : { foo: 1, bar: 2 },
//      indicator  : 'add_indicator',
//      onComplete : function(args) {
//          // do something
//      }
//  });
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.Ajax = {};
Smolder.Ajax.request = function(args) {
    var url       = args.url;
    var params    = args.params || {};
    var indicator = args.indicator;
    var complete  = args.onComplete || Prototype.emptyFunction;;

    // tell the user that we're doing something
    Smolder.show_indicator(indicator);

    // add the ajax=1 flag to the existing query params
    params.ajax = 1;

    new Ajax.Request(
        url,
        {
            parameters  : params,
            asynchronous: true,
            evalScripts : true,
            onComplete : function(request, json) {
                if(! json ) json = {};
                Smolder.show_messages(json);

                // hide the indicator
                Smolder.hide_indicator(indicator);

                // do whatever else the caller wants
                args.request = request;
                args.json    = json || {};
                complete(args);
            },
            onException: function(request, exception) { alert("ERROR FROM AJAX REQUEST:\n" + exception) },
            onFailure: function(request) { Smolder.show_error() }
        }
    );
};

///////////////////////////////////////////////////////////////////////////////////////////////////
// FUNCTION: Smolder.Ajax.update
// takes the following named args
// url       : the full url of the request (required)
// parmas    : an object of query params to send along
// target    : the id of the element receiving the contents (optional defaults to 'content')
// indicator : the id of the image to use as an indicator (optional defaults to 'indicator')
// onComplete: a call back function to be executed after the normal processing (optional)
//              Receives as arguments, the same args passed into Smolder.Ajax.update
//
//  Smolder.Ajax.update({
//      url        : '/app/some_mod/something',
//      params     : { foo: 1, bar: 2 },
//      target     : 'div_id',
//      indicator  : 'add_indicator',
//      onComplete : function(args) {
//          // do something
//      }
//  });
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.Ajax.update = function(args) {
    var url       = args.url;
    var params    = args.params || {};
    var target    = args.target;
    var indicator = args.indicator;
    var complete  = args.onComplete || Prototype.emptyFunction;;

    // tell the user that we're doing something
    Smolder.show_indicator(indicator);

    // add the ajax=1 flag to the existing query params
    params.ajax = 1;

    // the default target
    if( target == null || target == '' )
        target = 'content';

    new Ajax.Updater(
        { success : target },
        url,
        {
            parameters  : params,
            asynchronous: true,
            evalScripts : true,
            onComplete : function(request, json) {
                Smolder.load(target, json);

                // hide the indicator
                Smolder.hide_indicator(indicator);

                // do whatever else the caller wants
                args.request = request;
                args.json    = json || {};
                complete(args);
            },
            onException: function(request, exception) { alert("ERROR FROM AJAX REQUEST:\n" + exception) },
            onFailure: function(request) { Smolder.show_error() }
        }
    );
};

///////////////////////////////////////////////////////////////////////////////////////////////////
// FUNCTION: Smolder.Ajax.form_update
// takes the following named args
// form      : the form object (required)
// 
// All other arguments are passed to the underlying Smolder.Ajax.update() call
//
//  Smolder.Ajax.form_update({
//      form   : formObj,
//      target : 'div_id'
//  });
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.Ajax.form_update = function(args) {
    var form    = args.form;
    args.url    = form.action;
    args.params = Form.serialize(form, true);
    if(! args.onComplete ) args.onComplete = Prototype.emptyFunction;;

    // disable all of the inputs of this form that
    // aren't already and remember which ones we disabled
    var form_disabled_inputs = Smolder.disable_form(form);
    var oldOnComplete = args.onComplete;
    args.onComplete = function(request, json) {
        oldOnComplete(request, json);
        // reset which forms are open
        Smolder.PopupForm.shown_popup_id = '';

        // if we have a form, enable all of the inputs
        // that we disabled
        Smolder.reenable_form(form, form_disabled_inputs);
    };

    // now submit this normally
    Smolder.Ajax.update(args);
};

Smolder.disable_form = function(form) {
    // disable all of the inputs of this form that
    // aren't already and remember which ones we disabled
    var disabled = [];
    $A(form.elements).each(
        function(input, i) { 
            if( !input.disabled ) {
                disabled.push(input.name);
                input.disabled = true;
            }
        }
    );
    return disabled;
};

Smolder.reenable_form = function(form, inputs) {
    // if we have a form, enable all of the inputs
    // that we disabled
    if( form && inputs.length > 0 ) {
        $A(inputs).each(
            function(name, i) {
                if( name && form.elements[name] )
                    form.elements[name].disabled = false;
            }
        );
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.show_error = function() {
    new Notify.Alert(
        $('ajax_error_container').innerHTML,
        {
            messagecolor : '#FFFFFF',
            autoHide     : 'false'
        }
    );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.PopupForm = {
    shown_popup_id: '',
    toggle: function(popup_id) {
        // first turn off any other forms showing of this type
        var old_popup_id = Smolder.PopupForm.shown_popup_id;
        if( old_popup_id != '' && $(old_popup_id) != null ) {
            Smolder.PopupForm.hide();
        }

        if( old_popup_id == popup_id ) {
            Smolder.PopupForm.shown_popup_id = '';
        } else {
            new Effect.SlideDown(popup_id, { duration: .1 });
            Smolder.PopupForm.shown_popup_id = popup_id;
        }
        return false;
    },
    show: function(popup_id) {
        if( Smolder.PopupForm.shown_popup_id != popup_id ) {
            Smolder.PopupForm.toggle(popup_id);
        }
    },
    hide: function() {
        new Effect.SlideUp( Smolder.PopupForm.shown_popup_id, { duration: .1 } );
        Smolder.PopupForm.shown_popup_id = '';
    }
};

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.changeSmokeGraph = function(form) {
    var type      = form.elements['type'].value;
    var url       = form.action + "/" + escape(type) + "?change=1&";

    // add each field that we want to see to the URL
    var fields = new Array('total', 'pass', 'fail', 'skip', 'todo', 'duration');
    fields.each(
        function(value, index) {
            if( form.elements[value].checked ) {
                url = url + escape(value) + '=1&';
            }
        }
    );

    // add any extra args that we might want to search by
    var extraArgs = ['start', 'stop', 'tag', 'platform', 'architecture'];
    for(var i = 0; i < extraArgs.length; i++) {
        var arg = extraArgs[i];
        if( form.elements[arg] != null && form.elements[arg].value != '') {
            url = url + arg + '=' + escape(form.elements[arg].value) + '&';
        }
    }

    $('graph_image').src = url;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.toggleSmokeValid = function(form) {
    // TODO - replace with one regex
    var trigger = form.id.replace(/_trigger$/, '');
    var smokeId = trigger.replace(/^(in)?valid_form_/, '');
    var divId = "smoke_test_" + smokeId;
    
    // we are currently not showing any other forms
    Smolder.PopupForm.shown_form_id = '';
    
    Smolder.Ajax.form_update({
        form      : form, 
        target    : divId, 
        indicator : trigger + "_indicator"
    });
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.newSmokeReportWindow = function(url) {
    window.open(
        url,
        'report_details',
        'resizeable=yes,width=850,height=600,scrollbars=yes'
    );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.makeFormAjaxable = function(element) {
    // find which element it targets
    var target;
    var matches = element.className.match(/(^|\s)for_([^\s]+)($|\s)/);
    if( matches != null )
        target = matches[2];

    // find which indicator it uses
    var indicatorId;
    matches = element.className.match(/(^|\s)show_([^\s]+)($|\s)/);
    if( matches != null )
        indicatorId = matches[2];

    element.onsubmit = function(event) {
        Smolder.Ajax.form_update({
            form      : element, 
            target    : target, 
            indicator : indicatorId
        });
        return false;
    };
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.makeLinkAjaxable = function(element) {
    var target;

    // find which target it targets
    var matches = element.className.match(/(^|\s)for_([^\s]+)($|\s)/);
    if( matches != null )
        target = matches[2];

    // find which indicator it uses
    var indicatorId;
    matches = element.className.match(/(^|\s)show_([^\s]+)($|\s)/);
    if( matches != null )
        indicatorId = matches[2];

    element.onclick = function(event) {
        Smolder.Ajax.update({
            url       : element.href, 
            target    : target, 
            indicator : indicatorId
        });
        return false;
    };
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.show_indicator = function(indicator) {
    indicator = $(indicator);
    if( indicator ) Element.show(indicator);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.hide_indicator = function(indicator) {
    indicator = $(indicator);
    if( indicator ) Element.hide(indicator);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.highlight = function(el) {
    new Effect.Highlight(
        el,
        {
            'startcolor'  : '#ffffff',
            'endcolor'    : '#ffff99',
            'restorecolor': '#ffff99'
        }
    );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.unHighlight = function(el) {
    new Effect.Highlight(
        el,
        {
            'startcolor'  : '#ffff99',
            'endcolor'    : '#ffffff',
            'restorecolor': '#ffffff'
        }
    );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.flash = function(el) {
    new Effect.Highlight(
        el,
        {
            'startcolor'  : '#ffff99',
            'endcolor'    : '#ffffff',
            'restorecolor': '#ffffff'
        }
    );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.show_messages = function(json) {
    if( json ) {
        var msgs = json.messages || [];
        msgs.each( function(msg) { Smolder.show_message(msg.type, msg.msg) } );
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.__message_count = 0;
Smolder.message_template = new Template('<div class="#{type}" id="message_#{count}">#{text}</div>');
Smolder.show_message = function(type, text) {
    Smolder.__message_count++;
    // insert it at the top of the messages
    $('message_container').insert({ 
        top: Smolder.message_template.evaluate({
            type  : type, 
            count : Smolder.__message_count, 
            text  : text
        }) 
    });

    // fade it out after 10 secs, or onclick
    var el = $('message_' + Smolder.__message_count);
    var fade = function() { new Effect.Fade(el, { duration: .4 } ); };
    el.onclick = fade;
    setTimeout(fade, 7000);
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.setup_tooltip = function(trigger, target) {
    trigger.onclick = function() {
       new Effect.toggle(target, 'appear', { duration: .4 });
    };
}

// CRUD abstraction for Smolder
Smolder.__known_CRUDS = { };
Smolder.CRUD = Class.create();

/* Class methods */
Smolder.CRUD.find     = function(id)   { return Smolder.__known_CRUDS[id] };
Smolder.CRUD.remember = function(crud) { Smolder.__known_CRUDS[crud.div.id] = crud; };
Smolder.CRUD.forget   = function(crud) { Smolder.__known_CRUDS[crud.div.id] = false; };

/* Object methods */
Object.extend(Smolder.CRUD.prototype, {
    initialize: function(id, url) {
        this.div      = $(id);
        this.url      = url;
        this.list_url = url + '/list';

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
                target     : this.list_container_id,
                indicator  : 'delete_indicator_' + itemId
            });
            return false;
        }.bindAsEventListener(this);
        
        // show the popup form
        var popup = 'delete_' + itemId;
        Smolder.PopupForm.toggle(popup);
    },
    submit_change: function(form) {

        // find the add_inidicator
        var indicator = $(this.add_container).select('.add_indicator')[0].id;
        Smolder.Ajax.form_update({
            form       : form,
            target     : this.add_container.id,
            indicator  : indicator,
            onComplete : function(args) {
                if(! args.json ) args.json = {};
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
            indicator : this.indicator,
            target    : this.list_container_id
        });
    }
});


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
// These are our JS behaviors that are applied externally to HTML elements just like CSS
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
var myrules = {
    'a.calendar_trigger'  : function(element) {
        // now find the id's of the calendar div and input based on the id of the trigger
        // triggers are named $inputId_calendar_trigger, and calendar divs are named 
        // $inputId_calendar
        var inputId = element.id.replace(/_calendar_trigger/, '');
        var input = $(inputId);

        Calendar.setup({
            inputField  : input.name,
            ifFormat    : "%m/%d/%Y",
            button      : element.id,
            weekNumbers : false,
            showOthers  : true,
            align       : 'CL',
            cache       : true
        });
    },
    
    'a.smoke_reports_nav' : function(element) {
        // set the limit and then do an ajax request for the form
        element.onclick = function() {
            var offset = 0;
            var matches = element.className.match(/(^|\s)offset_([^\s]+)($|\s)/);
            if( matches != null )
                offset = matches[2];
            $('smoke_reports').elements['offset'].value = offset;
            Smolder.Ajax.form_update({
                form      : $('smoke_reports'),
                indicator : 'paging_indicator'
            });
            return false;
        };
    },

    'form.change_smoke_graph'  : function(element) {
        element.onsubmit = function() {
            Smolder.changeSmokeGraph(element);
            return false;
        }
    },

    'a.popup_form' : function(element) {
        var popupId = element.id.replace(/_trigger$/, '');
        element.onclick = function() {
            Smolder.PopupForm.toggle(popupId);
            return false;
        };
    },

    'input.cancel_popup' : function(element) {
        element.onclick = function() {
            Smolder.PopupForm.hide();
        };
    },

    'form.toggle_smoke_valid' : function(element) {
        element.onsubmit = function() {
            Smolder.toggleSmokeValid(element);
            return false;
        }
    },

    '#platform_auto_complete' : function(element) {
        new Ajax.Autocompleter(
            'platform',
            'platform_auto_complete',
            '/app/developer_projects/platform_options'
        );
    },

    '#architecture_auto_complete' : function(element) {
        new Ajax.Autocompleter(
            'architecture', 
            'architecture_auto_complete', 
            '/app/developer_projects/architecture_options'
        );
    },

    'input.auto_submit' : function(element) {
        element.onchange = function(event) {
            element.form.onsubmit();
            return false;
        }
    },

    'select.auto_submit' : function(element) {
        element.onchange = function(event) {
            element.form.onsubmit();
            return false;
        }
    },
    
    // for ajaxable forms and anchors the taget div for updating is determined
    // as follows:
    // Specify a the target div's id by adding a 'for_$id' class to the elements
    // class list:
    //      <a class="ajaxable for_some_div" ... >
    // This will make the target a div named "some_div"
    // If no target is specified, then it will default to "content"
    'a.ajaxable' : function(element) {
        Smolder.makeLinkAjaxable(element);
    },

    'form.ajaxable' : function(element) {
        Smolder.makeFormAjaxable(element);
    },

    'div.crud' : function(element) {
        var matches = element.className.match(/(^|\s)for_(\w+)($|\s)/);
        var url     = "/app/" + matches[2];
        new Smolder.CRUD(element.id, url);
    },
    'form.resetpw_form': function(element) {
        Smolder.makeFormAjaxable(element);
        // extend the onsubmit handler to turn off the popup
        var popupId = element.id.replace(/_form$/, '');
        var oldOnSubmit = element.onsubmit;
        element.onsubmit = function() {
            oldOnSubmit();
            Smolder.PopupForm.toggle(popupId);
            return false;
        };
    },
    // on the preferences form, the project selector should update
    // the preferences form with the selected projects preferences
    // from the server
    '#project_preference_selector': function(element) {
        var form  = element.form;
    
        // if we start off looking at the default options
        if( element.value == form.elements['default_pref_id'].value ) {
            Element.show('dev_prefs_sync_button');
            // if we want to show some info - Element.show('default_pref_info');
        }

        element.onchange = function() {

            // if we are the default preference, then show the stuff
            // that needs to be shown
            if( element.value == form.elements['default_pref_id'].value ) {
                Element.show('dev_prefs_sync_button');
                // if we want to show some info - Element.show('default_pref_info');
            } else {
                Element.hide('dev_prefs_sync_button');
                // if we want to show some info - Element.hide('default_pref_info');
            }
    
            // get the preference details from the server
            Smolder.show_indicator('pref_indicator');
            new Ajax.Request(
                '/app/developer_prefs/get_pref_details',
                {
                    parameters: Form.serialize(form),
                    asynchronous: true,
                    onComplete: function(response, json) {
                        // for every value in our JSON response, set that
                        // same element in the form
                        $A(['email_type', 'email_freq', 'email_limit']).each(
                            function(name) {
                                var elm = form.elements[name];
                                elm.value = json[name];
                                Smolder.flash(elm);
                            }
                        );
                        Smolder.hide_indicator('pref_indicator');
                    },
                    onFailure: function() { Smolder.show_error() }
                }
            );
        };
    },
    // submit the preference form to sync the other preferences
    '#dev_prefs_sync_button': function(element) {
        element.onclick = function() {
            var form = $('update_pref');
            form.elements['sync'].value = 1;
            Smolder.Ajax.form_update({ 
                form   : form,
                target : 'developer_prefs'
            });
        };
    },
    // hightlight selected text, textarea and select inputs
    'input.hl': function(element) {
        element.onfocus = function() { Smolder.highlight(element);   };
        element.onblur  = function() { Smolder.unHighlight(element); };
    },
    'textarea.hl': function(element) {
        element.onfocus = function() { Smolder.highlight(element);   };
        element.onblur  = function() { Smolder.unHighlight(element); };
    },
    'select.hl': function(element) {
        element.onfocus = function() { Smolder.highlight(element);   };
        element.onblur  = function() { Smolder.unHighlight(element); };
    },

    // setup tooltips
    '.tooltip_trigger': function(element) {
        var matches = element.className.match(/(^|\s)for_([^\s]+)($|\s)/);
        if( matches ) {
            var target  = matches[2];
            if( target ) {
                Smolder.setup_tooltip(element, $(target));
                Smolder.setup_tooltip($(target), $(target));
            }
        }
    },
    // TAP Matrix triggers for more test file details
    '.tap a.testfile_details_trigger' : function(el) {
        // get the id of the target div
        var matches = el.id.match(/^for_(.*)$/);
        var target = matches[1];
        // get the id of the indicator image
        matches = el.className.match(/(^|\s)show_(\S*)($|\s)/);
        var indicator = matches[2];

        el.onclick = function() {
            if( Element.visible(target) ) {
                $(target + '_tap_stream').hide();
                Effect.BlindUp(target, { duration: .1 });
            } else {
                $(indicator).style.visibility = 'visible';
                Smolder.Ajax.update({
                    url        : el.href,
                    target     : target,
                    indicator  : 'none',
                    onComplete : function() {
                        window.setTimeout(function() { $(indicator).style.visibility = 'hidden'}, 200);
                        Effect.BlindDown(
                            target,
                            // reapply any dynamic bits
                            { 
                                afterFinish : function() { 
                                    $(target + '_tap_stream').show();
                                    $$('.tooltip_trigger').each(function(el) {
                                        var diag = $(el).select('.tooltip')[0];
                                        Smolder.setup_tooltip(el, diag);
                                    });
                                },
                                duration    : .1
                            }
                        );
                    }
                });
            }
            return false;
        };
    },
    '.tap div.diag': function(el) {
        Smolder.setup_tooltip(el, el);
    },
    '.tap a.toggle_all_tests' : function(el) {
    	el.onclick = function() {
            $$('a.toggle_all_tests span.hide', 'a.toggle_all_tests span.show').invoke('toggle');
	    $$('tbody.results.passed').invoke('toggle');
        };
    },
    '.tap a.show_all' : function(el) {
        Event.observe(el, 'click', function() {
            // an anonymous function that we use as a callback after each
            // panel is opened so that it opens the next one
            var show_details = function(index) {
                var el = $('testfile_details_' + index);
                // apply the behaviours if we're the last one
                if( ! el ) {
                    Behaviour.apply();
                    return;
                } 

                // we only need to fetch it if we're not already visible
                if( Element.visible(el) ) {
                    show_details(++index);
                } else {
                    matches = el.id.match(/^testfile_details_(\d+)$/);
                    var index = matches[1];
                    var indicator = $('indicator_' + index);
                    var div = $('testfile_details_' + index);
                    indicator.style.visibility = 'visible';
                    
                    Smolder.Ajax.update({
                        url        : $('for_testfile_details_' + index).href,
                        target     : div,
                        indicator  : 'none',
                        onComplete : function() {
                            Element.show(div);
                            indicator.style.visibility = 'hidden';
                            show_details(++index);
                        }
                    });
                }
            };
            show_details(0);
        });
    }
};

Behaviour.register(myrules);
