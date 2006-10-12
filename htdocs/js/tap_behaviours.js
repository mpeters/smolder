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
        el.onclick = function() {
           new Effect.toggle(el, 'appear');
        };
    },
    'td.diag' : function(el) {
        var diag = document.getElementsByClassName('diag', el)[0];
        if( diag ) {
            el.onclick = function() {
                new Effect.toggle(diag, 'appear');
            };
        }
    }
};

Behaviour.register(myrules);
