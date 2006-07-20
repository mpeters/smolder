///////////////////////////////////////////////////////////////////////////////////////////////////
// FUNCTION: ajax_form_submit
// takes the following named args
// form      : the form object (required)
// 
// All other arguments are passed to the underlying ajax_submit() call
//
//  ajax_form_submit({
//      form: formObj,
//      div : 'div_name'
//  });
///////////////////////////////////////////////////////////////////////////////////////////////////
function ajax_form_submit(args) {
    var form = args['form'];
    var url = form.action;
    var queryParams = Form.serialize(form);
    args['url'] = url + "?" + queryParams;

    ajax_submit(args);
};

///////////////////////////////////////////////////////////////////////////////////////////////////
// FUNCTION: ajax_submit
// takes the following named args
// url       : the full url of the request (required)
// div       : the id of the div receiving the contents (optional defaults to 'content')
// indicator : the id of the image to use as an indicator (optional defaults to 'indicator')
// onComplete: a call back function to be executed after the normal processing (optional)
//              Receives as arguments, the same args passed into ajax_submit
//
//  ajax_submit({
//      url        : '/app/some_mod/something',
//      div        : 'div_name',
//      indicator  : 'add_indicator',
//      onComplete : function(args) {
//          // do something
//      }
//  });
///////////////////////////////////////////////////////////////////////////////////////////////////
function ajax_submit (args) {
    var url       = args['url'];
    var div       = args['div'];
    var indicator = args['indicator'];
    var complete  = args['onComplete'] || Prototype.emptyFunction;;

    // tell the user that we're doing something
    showIndicator(indicator);

    // add the ajax=1 flag to the existing query params
    var url_parts = url.split("?");
    var query_params;
    if( url_parts[1] == null || url_parts == '' ) {
        query_params = 'ajax=1'
    } else {
        query_params = url_parts[1] + '&ajax=1'
    }

    // the default div
    if( div == null || div == '' )
        div = 'content';

    new Ajax.Updater(
        { success : div, },
        url_parts[0],
        {
            parameters  : query_params,
            asynchronous: true,
            onComplete : function(request) {
                // reapply any dynamic bits
                Behaviour.apply();
                Tooltip.setup();
                // reset which forms are open
                shownPopupForm = '';
                shownForm = '';
                // hide the indicator
                hideIndicator(indicator);
                // do whatever else the user wants
                complete(args);
            },
            onFailure: function(request) { show_error() }
        }
    );
};

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function show_error() {
    new Notify.Alert(
        $('ajax_error_container').innerHTML,
        {
            messagecolor : '#FFFFFF',
            autoHide     : 'false',
        }
    );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function new_accordion (element_name, height) {
    new Rico.Accordion(
        $(element_name),
        {
            panelHeight         : height,
            expandedBg          : '#C47147',
            expandedTextColor   : '#FFFFFF',
            collapsedBg         : '#555555',
            collapsedTextColor  : '#FFFFFF',
            hoverBg             : '#BBBBBB',
            hoverTextColor      : '#555555',
            borderColor         : '#DDDDDD',

        }
    );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
var shownPopupForm = '';
function togglePopupForm(formId) {

    // first turn off any other forms showing of this type
    if( shownPopupForm != '' && $(shownPopupForm) != null ) {
        new Effect.SlideUp( shownPopupForm );
    }

    if( shownPopupForm == formId ) {
        shownPopupForm = '';
    } else {

        new Effect.SlideDown(formId);
        shownPopupForm = formId;
    }
    return false;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function changeSmokeGraph(form) {
    var projectId = form.id.replace(/^change_smoke_graph_/, '');
    var type      = form.elements['type'].value;
    var url       = "/app/developer_graphs/image/" + projectId + "/" + escape(type) + "?change=1&";

    // add each field that we want to see to the URL
    var fields = new Array('total', 'pass', 'fail', 'skip', 'todo');
    fields.each(
        function(value, index) {
            if( form.elements[value].checked ) {
                url = url + escape(value) + '=1&';
            }
        }
    );

    // add any extra args that we might want to search by
    var extraArgs = ['start', 'stop', 'category', 'platform', 'architecture', 'category'];
    for(var i = 0; i < extraArgs.length; i++) {
        var arg = extraArgs[i];
        if( form.elements[arg] != null && form.elements[arg].value != '') {
            url = url + arg + '=' + escape(form.elements[arg].value) + '&';
        }
    }

    $('graph_image').src = url;
    new Effect.Highlight(
        $('graph_container'), 
        { 
            startcolor  : '#FFFF99',
            endcolor    : '#FFFFFF',
            restorecolor: '#FFFFFF'
        }
    );
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function toggleSmokeValid(form) {
    // TODO - replace with one regex
    var trigger = form.id.replace(/_trigger$/, '');
    var smokeId = trigger.replace(/^(in)?valid_form_/, '');
    var divId = "smoke_test_" + smokeId;
    
    // we are currently not showing any other forms
    // XXX - this is a global... probably not the best way to do this
    shownForm = '';
    
    ajax_form_submit({
        form      : form, 
        div       : divId, 
        indicator : trigger + "_indicator"
    });
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function newSmokeReportWindow(url) {
    window.open(
        url,
        'report_details',
        'resizeable=yes,scrollbars=yes'
    );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function makeFormAjaxable(element) {
    // find which div it targets
    var divId;
    var matches = element.className.match(/(^|\s)for_([^\s]+)($|\s)/);
    if( matches != null )
        divId = matches[2];

    // find which indicator it uses
    var indicatorId;
    matches = element.className.match(/(^|\s)show_([^\s]+)($|\s)/);
    if( matches != null )
        indicatorId = matches[2];

    element.onsubmit = function(event) {
        ajax_form_submit({
            form      : element, 
            div       : divId, 
            indicator : indicatorId
        });
        return false;
    };
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function makeLinkAjaxable(element) {
    var divId;

    // find which div it targets
    var matches = element.className.match(/(^|\s)for_([^\s]+)($|\s)/);
    if( matches != null )
        divId = matches[2];

    // find which indicator it uses
    var indicatorId;
    matches = element.className.match(/(^|\s)show_([^\s]+)($|\s)/);
    if( matches != null )
        indicatorId = matches[2];

    element.onclick = function(event) {
        ajax_submit({
            url       : element.href, 
            div       : divId, 
            indicator : indicatorId
        });
        return false;
    };
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function showIndicator(indicator) {
    indicator = $(indicator);
    if( indicator != null )
        Element.show(indicator);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function hideIndicator(indicator) {
    indicator = $(indicator);
    if( indicator != null )
        Element.hide(indicator);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function highlight(el) {
    new Effect.Highlight(
        el,
        {
            'startcolor'  : '#ffffff',
            'endcolor'    : '#ffff99',
            'restorecolor': '#ffff99',
        }
    );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function unHighlight(el) {
    new Effect.Highlight(
        el,
        {
            'startcolor'  : '#ffff99',
            'endcolor'    : '#ffffff',
            'restorecolor': '#ffffff',
        }
    );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
function flash(el) {
    new Effect.Highlight(
        el,
        {
            'startcolor'  : '#ffff99',
            'endcolor'    : '#ffffff',
            'restorecolor': '#ffffff',
        }
    );
}





