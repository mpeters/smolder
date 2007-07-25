/*
    Behaviour
    Class is inspired from Ben Nolan's behaviour.js script
    (http://bennolan.com/behaviour/) but uses Prototype's
    $$() and Element.getElementsBySelector() functions since
    they support more CSS syntax and are already loaded with
    prototype.
*/

var Behaviour = {
    rules : $H({}),
    register : function(new_rules) {
        Behaviour.rules.merge(new_rules);
    },
    apply : function(el) {
        Behaviour.rules.each(function(pair) {
            var rule = pair.key;

//var start_time = new Date().valueOf();
//console.log('applying: ' + rule);
            var behaviour = pair.value;
            // if we have an element, use Element.getElementsBySelector()
            // else use $$() to find the targets
            var targets;
            if( el ) {
                targets = $(el).getElementsBySelector(rule);
            } else {
                targets = $$(rule);
            }

            // if we got anything back then apply the behaviour
            if( targets.size() > 0 ) {
                targets.each(function(target) { behaviour(target) });
            }
//var end_time = new Date().valueOf();
//console.log('  took: ' + (end_time - start_time) + 'ms');
        });
    }
};
 
