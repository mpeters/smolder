var myrules = {
    'a.calendar_trigger'  : function(element) {
        // remove a possible previous calendar
        if( element.calendar != null )
            Element.remove(element.calendar);

        // now find the id's of the calendar div and input based on the id of the trigger
        // triggers are named $inputId_calendar_trigger, and calendar divs are named 
        // $inputId_calendar
        var calId = element.id.replace(/_trigger$/, '');
        var inputId = element.id.replace(/_calendar_trigger/, '');

        // remove anything that might be attached to the calendar div
        // this prevents multiple calendars from being created for the same
        // trigger if Behaviour.apply() is called
        $(calId).innerHTML = '';
        new DatePicker(
            calId, 
            inputId, 
            element.id, 
            { 
                format: DateUtil.simpleFormat('MM/dd/yyyy') 
            }
        );
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
            Smolder.togglePopupForm(popupId);
            return false;
        };
    },

    'input.cancel_popup' : function(element) {
        element.onclick = function() {
            Smolder.hidePopupForm();
        };
    },

    'a.smoke_report_window' : function(element) {
        element.onclick = function() {
            Smolder.newSmokeReportWindow(element.href);
            return false;
        }
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
        if( ! Smolder.CRUD.exists(element.id) ) {
            new Smolder.CRUD(element.id, url);
        }
    },
    'form.resetpw_form': function(element) {
        Smolder.makeFormAjaxable(element);
        // extend the onsubmit handler to turn off the popup
        var popupId = element.id.replace(/_form$/, '');
        var oldOnSubmit = element.onsubmit;
        element.onsubmit = function() {
            oldOnSubmit();
            Smolder.togglePopupForm(popupId);
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
        var target  = matches[2];
        if( target ) {
            Smolder.setup_tooltip(element, $(target));
            Smolder.setup_tooltip($(target), $(target));
        }
    }
};

Behaviour.register(myrules);
