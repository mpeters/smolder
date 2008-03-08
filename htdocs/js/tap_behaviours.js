var myrules = {
    // TAP Matrix triggers for more test file details
    'a.testfile_details_trigger' : function(el) {
        // get the id of the target div
        var matches = el.id.match(/^for_(.*)$/);
        var target = matches[1];
        // get the id of the indicator image
        matches = el.className.match(/(^|\s)show_(\S*)($|\s)/);
        var indicator = matches[2];

        el.onclick = function() {
            if( Element.visible(target) ) {
                Effect.BlindUp(target, { duration: .5 });
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
                                    Behaviour.apply(target); 
                                },
                                duration    : .5
                            }
                        );
                    }
                });
            }
            return false;
        };
    },
    'div.diag': function(el) {
        Smolder.setup_tooltip(el, el);
    },
    'td.tooltip_trigger' : function(el) {
        var diag = $(el).select('.tooltip')[0];
        Smolder.setup_tooltip(el, diag);
    },
    'a.show_all' : function(el) {
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

