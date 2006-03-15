function ajax_form_submit(form, div_name, indicator) {
    var url = form.action;
    var queryParams = Form.serialize(form);

    ajax_submit(
        url + "?" + queryParams,
        div_name,
        indicator
    );
};

function ajax_submit (url, div_name, indicator) {
    // tell the user that we're doing something
    indicator = $(indicator);
    if( indicator != null )
        Element.show(indicator);

    // add the ajax=1 flag to the existing query params
    var url_parts = url.split("?");
    var query_params;
    if( url_parts[1] == null || url_parts == '' ) {
        query_params = 'ajax=1'
    } else {
        query_params = url_parts[1] + '&ajax=1'
    }

    // the default div_name
    if( div_name == null )
        div_name = 'content';

    new Ajax.Updater(
        { success : div_name, },
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
                if( indicator != null )
                    Element.hide(indicator);
            }
        }
    );
};

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

function changeSmokeGraph(form) {
    var projectId = form.id.replace(/^change_smoke_graph_/, '');
    var type      = form.elements['type'].value;
    var url       = "/app/developer_graphs/image/" + projectId + "/" + escape(type) + "?change=1&";
    var start     = form.elements['start'].value;
    var stop      = form.elements['stop'].value;
    var category  = '';
    if( form.elements['category'] != null )
        category = form.elements['category'].value;

    // add each field to the URL
    var fields = new Array('total', 'pass', 'fail', 'skip', 'todo');
    fields.each(
        function(value, index) {
            if( form.elements[value].checked ) {
                url = url + escape(value) + '=1&';
            }
        }
    );

    if( start != '' )
        url = url + 'start=' + escape(start) + '&';
    if( stop != '' )
        url = url + 'stop=' + escape(stop) + '&';
    if( category != '' )
        url = url + 'category=' + escape(category) + '&';

    $('graph_image').src = url;
    new Effect.Highlight($('graph_container'), { startcolor: '#c3c3c3' });
}


function toggleSmokeValid(form) {
    // TODO - replace with one regex
    var trigger = form.id.replace(/_trigger$/, '');
    var smokeId = trigger.replace(/^(in)?valid_form_/, '');
    var divId = "smoke_test_" + smokeId;
    
    // we are currently not showing any other forms
    // XXX - this is a global... probably not the best way to do this
    shownForm = '';
    
    ajax_form_submit(form, divId, trigger + "_indicator");
}

function newSmokeReportWindow(url) {
    window.open(
        url,
        'report_details',
        'resizeable, width=750, height=600, scrollable'
    );
}

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
        ajax_form_submit(element, divId, indicatorId);
        return false;
    };
}

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
        ajax_submit(element.href, divId, indicatorId);
        return false;
    };
}





