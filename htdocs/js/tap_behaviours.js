var myrules = {
    // TAP Matrix triggers for more test file details
    'a.testfile_details_trigger' : function(el) {
        // get the id of the target div
        var matches = el.id.match(/^for_(.*)$/);
        var targetId = matches[1];
        // get the id of the indicator image
        matches = el.className.match(/(^|\s)show_(\S*)($|\s)/);
        var indicator = matches[2];

        el.onclick = function() {
            if( Element.visible(targetId) ) {
                Effect.BlindUp(targetId);
            } else {
                ajax_submit({
                    url: el.href,
                    div: targetId,
                    indicator: indicator,
                    onComplete: function() {
                        Effect.BlindDown(
                            targetId,
                            // reapply any dynamic bits
                            { afterFinish : function() { Behaviour.apply(); } }
                        );
                    }
                });
            }
            return false;
        };
    },
    'div.diag': function(el) {
        setup_tooltip(el, el);
    },
    'td.tooltip_trigger' : function(el) {
        var diag = document.getElementsByClassName('tooltip', el)[0];
        setup_tooltip(el, diag);
    }
};

Behaviour.register(myrules);
