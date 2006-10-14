var myrules = {
    'div.boxed': function(element) {
        shadowify(element);
    },
    'table.boxed': function(element) {
        shadowify(element);
    },
    '#top_nav a.dropdownmenu' : function(element) {
        var menuId = element.id.replace(/_trigger$/, '');
        element.onmouseover = function(event) {
            dropdownmenu(element, event, menuId);
        };
    },

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
            ajax_form_submit({
                form      : $('smoke_reports'),
                indicator : 'paging_indicator'
            });
            return false;
        };
    },

    'form.change_smoke_graph'  : function(element) {
        element.onsubmit = function() {
            changeSmokeGraph(element);
            return false;
        }
    },

    'a.popup_form' : function(element) {
        var popupId = element.id.replace(/_trigger$/, '');
        element.onclick = function() {
            togglePopupForm(popupId);
            return false;
        };
    },

    'a.smoke_report_window' : function(element) {
        element.onclick = function() {
            newSmokeReportWindow(element.href);
            return false;
        }
    },

    'form.toggle_smoke_valid' : function(element) {
        element.onsubmit = function() {
            toggleSmokeValid(element);
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
        makeLinkAjaxable(element);
    },

    'form.ajaxable' : function(element) {
        makeFormAjaxable(element);
    },

    'div.draggable_developer' : function(element) {
        new Draggable(element.id, {revert:true, ghosting: true})
    },

    'div.draggable_project_developer' : function(element) {
        new Draggable(element.id, {revert:true})
    },

    'div.droppable_project' : function(element) {
        Droppables.add(
            element.id,
            {
                accept      : 'draggable_developer',
                hoverclass  : 'droppable_project_active',
                onDrop      : function(developer) {
                    var dev_id = developer.id.replace(/^developer_/, '');
                    var proj_id = element.id.replace(/^project_/, '');
                    var url = "/app/admin_projects/add_developer?ajax=1&project=" 
                        + proj_id + "&developer=" + dev_id;
                    ajax_submit({
                        url : url,
                        div : "project_container_" + proj_id
                    });
                }
            }
        );
    },

    '#droppable_trash_can' : function(element) {
        Droppables.add(
            element.id,
            {
                accept      : 'draggable_project_developer',
                hoverclass  : 'active',
                onDrop      : function(project_developer) {
                    var matches = project_developer.id.match(/project_(\d+)_developer_(\d+)/);
                    var url = "/app/admin_projects/remove_developer?ajax=1&project=" 
                        + matches[1] + "&developer=" + matches[2];
                    ajax_submit({
                        url : url,
                        div : "project_container_" + matches[1] 
                    });
                    Element.hide(project_developer);
                }
            }
        );
    },

    'div.accordion' : function(element) {
        // determine the height for each panel
        // this is taken from a class whose name is "at_$height"
        var matches = element.className.match(/(^|\s)at_(\d+)($|\s)/);
        var height;
        if( matches != null )
            height = matches[2];
        else
            height = 100;
            
        
        new_accordion(element.id, height);
    },
    'div.crud' : function(element) {
        var matches = element.className.match(/(^|\s)for_(\w+)($|\s)/);
        var url     = "/app/" + matches[2];
        if( ! CRUD.exists(element.id) ) {
            new CRUD(element.id, url);
        }
    },
    'form.resetpw_form': function(element) {
        makeFormAjaxable(element);
        // extend the onsubmit handler to turn off the popup
        var popupId = element.id.replace(/_form$/, '');
        var oldOnSubmit = element.onsubmit;
        element.onsubmit = function() {
            oldOnSubmit();
            togglePopupForm(popupId);
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
            show_indicator('pref_indicator');
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
                                flash(elm);
                            }
                        );
                        hideIndicator('pref_indicator');
                    },
                    onFailure: function() { show_error() }
                }
            );
        };
    },
    // submit the preference form to sync the other preferences
    '#dev_prefs_sync_button': function(element) {
        element.onclick = function() {
            var form = $('update_pref');
            form.elements['sync'].value = 1;
            ajax_form_submit({ 
                form : form,
                div  : 'developer_prefs'
            });
        };
    },
    // hightlight selected text, textarea and select inputs
    'input.hl': function(element) {
        element.onfocus = function() { highlight(element);   };
        element.onblur  = function() { unHighlight(element); };
    },
    'textarea.hl': function(element) {
        element.onfocus = function() { highlight(element);   };
        element.onblur  = function() { unHighlight(element); };
    },
    'select.hl': function(element) {
        element.onfocus = function() { highlight(element);   };
        element.onblur  = function() { unHighlight(element); };
    },
    // TAP Matrix triggers for more test file details
    'a.testfile_details_trigger' : function(element) {
        // get the id of the target div
        var matches = element.id.match(/^for_(.*)$/);
        var targetId = matches[0];
        // get the id of the indicator image
        matches = element.className.match(/(^|\s)show_(.*)($|\s)/);
        var indicator = matches[1];

        element.onclick = function() {
            if( Element.visible(targetId) ) {
                Effect.SlideUp(targetId);
            } else {
                ajax_submit({
                    url: element.href,
                    div: targetId,
                    indicator: indicator,
                    onComplete: function() {
                        Effect.SlideDown(targetId);
                    }
                });
            }
            return false;
        };
    }
};

Behaviour.register(myrules);
