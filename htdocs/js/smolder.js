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
                Smolder.show_messages(json);

                // hide the indicator
                Smolder.hide_indicator(indicator);

                // do whatever else the caller wants
                args.request = request;
                args.json    = json;
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
                args.json    = json;
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
    var disabled = [];
    $A(form.elements).each(
        function(input, i) { 
            if( !input.disabled ) {
                disabled.push(input.name);
                input.disabled = true;
            }
        }
    );
    form_disabled_inputs = Smolder.disable_form(form);
    var oldOnComplete = args.onComplete;
    args.onComplete = function(request, json) {
        oldOnComplete(request, json);
        // reset which forms are open
        Smolder._shownPopupForm = '';
        Smolder._shownForm = '';

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
Smolder.new_accordion = function(element_name, height) {
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
            borderColor         : '#DDDDDD'
        }
    );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder._shownPopupForm = '';
Smolder._shownForm = '';
Smolder.togglePopupForm = function(formId) {

    // first turn off any other forms showing of this type
    if( Smolder._shownPopupForm != '' && $(Smolder._shownPopupForm) != null ) {
        new Effect.SlideUp( Smolder._shownPopupForm, { duration: .5 } );
    }

    if( Smolder._shownPopupForm == formId ) {
        Smolder._shownPopupForm = '';
    } else {
        new Effect.SlideDown(formId, { duration: .5 });
        Smolder._shownPopupForm = formId;
    }
    return false;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.changeSmokeGraph = function(form) {
    var type      = form.elements['type'].value;
    var url       = form.action + "/" + escape(type) + "?change=1&";

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

    var img = $('graph_image');
    img.onload = function() {
        new Effect.Highlight(
            $('graph_container'), 
            { 
                startcolor  : '#FFFF99',
                endcolor    : '#FFFFFF',
                restorecolor: '#FFFFFF'
            }
        );
    };
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
    Smolder._shownForm = '';
    
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
Smolder.show_message = function(type, text) {
    Smolder.__message_count++;
    // insert it at the top of the messages
    new Insertion.Top(
        $('message_container'),
        '<div class="' + type + '" id="message_' + Smolder.__message_count + '">' + text + '</div>'
    );

    // fade it out after 10 secs, or onclick
    var el = $('message_' + Smolder.__message_count);
    var fade = function() { new Effect.Fade(el, { duration: .4 } ); };
    el.onclick = fade;
    setTimeout(fade, 10000);
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
Smolder.setup_tooltip = function(trigger, target) {
    trigger.onclick = function() {
       new Effect.toggle(target, 'appear', { duration: .4 });
    };
}
