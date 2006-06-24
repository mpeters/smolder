var CRUD_ADD_SHOWN    = false;
var CRUD_EDIT_SHOWN   = false;
var CRUD_LIST_UPDATED = true;

var myrules = {
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

    'input.first' : function(element) {
        element.focus();
        highlight(element);
    },
    '#crud_add_trigger': function(element) {
        var container = 'crud_add_container';
        element.onclick = function() {
            if( CRUD_ADD_SHOWN ) {
                Effect.SlideUp(container);
                CRUD_ADD_SHOWN  = false;
                CRUD_EDIT_SHOWN = false;
            } else {
                ajax_submit({
                    url        : element.href,
                    div        : container, 
                    indicator  : 'crud_indicator',
                    onComplete : function(args) {
                        if( ! CRUD_ADD_SHOWN && ! CRUD_EDIT_SHOWN ) {
                            Effect.SlideDown(args['div']); 
                        }
                        CRUD_ADD_SHOWN    = true;
                        CRUD_EDIT_SHOWN   = false;
                        CRUD_LIST_UPDATED = false;
                    }
                });
            }
            return false;
        };
    },
    '#crud_list_changed': function(element) {
        var target = 'crud_list';
        var matches   = element.className.match(/(^|\s)for_(\w+)($|\s)/);
        var url       = "/app/" + matches[2] + "/list?table_only=1";

        if( ! CRUD_LIST_UPDATED ) {
            ajax_submit({
                url       : url,
                div       : target,
                indicator : 'crud_indicator'
            });
            CRUD_LIST_UPDATED = true;
            CRUD_ADD_SHOWN    = false;
            CRUD_EDIT_SHOWN   = false;
        }
    },
    'a.crud_edit_trigger': function(element) {
        var container = 'crud_add_container'; 
        var matches   = element.className.match(/(^|\s)for_item_(\d+)($|\s)/);
        var itemId;
        itemId = matches[2];
        if( itemId != null ) {
            element.onclick = function() {
                ajax_submit({
                    url        : element.href,
                    div        : container,
                    indicator  : 'crud_indicator',
                    onComplete : function(args) {
                        if( ! CRUD_ADD_SHOWN && ! CRUD_EDIT_SHOWN ) {
                            Effect.SlideDown(args['div']);
                        }
                        CRUD_EDIT_SHOWN   = true;
                        CRUD_ADD_SHOWN    = false;
                        CRUD_LIST_UPDATED = false;
                    },
                });
                return false;
            };
        }
    },
    '#crud_edit_cancel': function(element) {
        element.onclick = function() {
            var container = 'crud_add_container';
            Effect.SlideUp(container);
            CRUD_ADD_SHOWN  = false;
            CRUD_EDIT_SHOWN = false;
        };
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
};

Behaviour.register(myrules);
