var myrules = {
    // TAP Matrix triggers for more test file details
    'a.testfile_details_trigger' : function(element) {
        // get the id of the target div
        var matches = element.id.match(/^for_(.*)$/);
        var targetId = matches[1];
        // get the id of the indicator image
        matches = element.className.match(/(^|\s)show_(\S*)($|\s)/);
        var indicator = matches[2];

        element.onclick = function() {
            if( Element.visible(targetId) ) {
                Effect.BlindUp(targetId);
            } else {
                ajax_submit({
                    url: element.href,
                    div: targetId,
                    indicator: indicator,
                    onComplete: function() {
                        Effect.BlindDown(targetId);
                    }
                });
            }
            return false;
        };
    }
};

Behaviour.register(myrules);
