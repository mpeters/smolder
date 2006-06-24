// Copyright (c) 2006 Tomoaki Kinoshita (http://script.spinelz.org/)
// 
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

/**
 * Element class
 */
Object.extend(Element, {

  getTagNodes: function(element, tree) {
    return this.getElementsByNodeType(element, 1, tree);
  },
  
  getTextNodes: function(element, tree) {
    return this.getElementsByNodeType(element, 3, tree);
  },
  
  getElementsByNodeType: function(element, nodeType, tree) {
    
    element = ($(element) || document.body);
    var nodes = element.childNodes;
    var result = [];
    
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].nodeType == nodeType)
        result.push(nodes[i]);
      if (tree && (nodes[i].nodeType == 1)) 
        result = result.concat(this.getElementsByNodeType(nodes[i], nodeType, tree));
    }
    
    return result;
  },
  
  getParentByClassName: function(className, element) {
    var parent = element.parentNode;
    if (!parent || (parent.tagName == 'BODY'))
      return null;
    else if (!parent.className) 
      return Element.getParentByClassName(className, parent);
    else if (Element.hasClassName(parent, className))
      return parent;
    else
      return Element.getParentByClassName(className, parent);
  },
  
  getParentByTagName: function(tagNames, element) {
    
    var parent = element.parentNode;
    if (parent.tagName == 'BODY')
      return null;
      
    var index = tagNames.join('/').toUpperCase().indexOf(parent.tagName.toUpperCase(), 0);
    
    if (index >= 0)
      return parent;
    else
      return Element.getParentByTagName(tagNames, parent);
  },
  
  getFirstElementByClassNames: function(element, classNames, tree) {
    
    if (!element || 
        !((typeof(classNames) == 'object') && (classNames.constructor == Array))) {
      return;  
    }
  
    element = (element || document.body);
    var nodes = element.childNodes;
    
    for (var i = 0; i < nodes.length; i++) {
      for (var j = 0; j < classNames.length; j++) {
        if (nodes[i].nodeType != 1) {
          continue;
        
        } else if (Element.hasClassName(nodes[i], classNames[j])) {
          return nodes[i];
        
        } else if (tree) {
          var result = this.getFirstElementByClassNames(nodes[i], classNames, tree);
          if (result) return result;
        }
      }
    }
    
    return;
  },
  
  getElementsByClassNames: function(element, classNames) {
    
    if (!element || 
        !((typeof(classNames) == 'object') && (classNames.constructor == Array))) {
      return;  
    }
  
    var nodes = [];
    classNames.each(function(c) {
      nodes = nodes.concat(document.getElementsByClassName(c, element));
    });
    
    return nodes;
  },
  
  getWindowHeight: function() {
      
    if (window.innerHeight) {
      return window.innerHeight; // Mozilla, Opera, NN4
    } else if (document.documentElement && document.documentElement.offsetHeight){ // ?? IE
      return document.documentElement.offsetHeight;
    } else if (document.body && document.body.offsetHeight) {
      return document.body.offsetHeight - 20;
    }
    return 0;
  },
  
  getWindowWidth:function() {
    
    if(window.innerWidth) {
      return window.innerWidth; // Mozilla, Opera, NN4
    } else if (document.documentElement && document.documentElement.offsetWidth){ // ?? IE
      return document.documentElement.offsetWidth - 20;
    } else if (document.body && document.body.offsetWidth){
      return document.body.offsetWidth - 20;
    }
    return 0;
  },
  
  getMaxZindex: function(element) {
    var target = $(element);
    if (!target) {
      target = document;
    }  
    
    var maxZindex = -1;
    if (target.style)
      maxZindex = new Number(Element.getStyle(target, "z-index"));  
    
    var tmpZindex = 0;
    var elements = target.childNodes;
    for (var i = 0; i < elements.length; i++) {
      tmpZindex = Element.getMaxZindex(elements[i]);
      if (maxZindex < tmpZindex)
        maxZindex = tmpZindex;
    }
      
    return maxZindex;
  }
});


/**
 * Array
 */
Object.extend(Array.prototype, {
  insert : function(index, element) {
    this.splice(index, 0 , element);
  },
  
  remove : function(index) {
    this.splice(index, 1);
  }
});


/**
 * String
 */
Object.extend(String.prototype, {
  
  getPrefix: function(delimiter) {
  
    if (!delimiter) delimiter = '_';
    return this.split(delimiter)[0];
  },
  
  getSuffix: function(delimiter) {
    
    if (!delimiter) delimiter = '_';
    return this.split(delimiter).pop();
  },

  appendPrefix: function(prefix, delimiter) {
  
    if (!delimiter) delimiter = '_';
    return this + delimiter + prefix;
  },
  
  appendSuffix: function(suffix, delimiter) {
  
    if (!delimiter) delimiter = '_';
    return this + delimiter + suffix;
  },
  
  // for firefox
  println: function() {
    dump(this + '\n');
  }
});


/**
 * CssUtil
 */
var CssUtil = Class.create();

CssUtil.appendPrefix = function(prefix, suffixes) {
  var newHash = {};
  $H(suffixes).each(function(pair) {
    newHash[pair[0]] = prefix + suffixes[pair[0]];
  });
  return newHash;
}

CssUtil.getCssRules = function(sheet) {
  return sheet.rules || sheet.cssRules;
}

CssUtil.getCssRuleBySelectorText = function(selector) {
  var rule = null;
  $A(document.styleSheets).each(function(s) {
    var rules = CssUtil.getCssRules(s);
    rule =  $A(rules).detect(function(r) {
      return r.selectorText == '.' + selector;
    });
    if (rule) throw $break;
  });
  return rule;
}

CssUtil.prototype = {
  
  initialize: function(styles) {
    if (!((typeof(styles) == 'object') && (styles.constructor == Array))) {
      throw 'CssUtil#initialize: argument must be a Array object!';    
    }
    
    this.styles = styles;
  },
  
  joinClassNames: function(key) {
    var strings = this.styles.collect(function(s) {
      return s[key];
    });
    return strings.join(' ');
  },
  
  addClassNames: function(element, key) {
    this.styles.each(function(s) {
      Element.addClassName(element, s[key]);
    });
  },
  
  removeClassNames: function(element, key) {
    this.styles.each(function(s) {
      Element.removeClassName(element, s[key]);
    });
  },
  
  refreshClassNames: function(element, key) {
    element.className = '';
    this.addClassNames(element, key);
  },
  
  hasClassName: function(element, key) {
    return this.styles.any(function(s) {
      return Element.hasClassName(element, s[key]);
    });
  }
}


/** 
 * Hover 
 */
var Hover = Class.create();
Hover.prototype = {

  initialize: function(element) {
    this.options = Object.extend({
      defaultClass: '',
      hoverClass: '',
      cssUtil: '',
      list: false
    }, arguments[1] || {});
    
    var element = $(element);
    if (this.options.list) {
      var nodes = element.childNodes;
      for (var i = 0; i < nodes.length; i++) {
        if (nodes[i].nodeType == 1) {
          this.build(nodes[i]);
        }
      }
    } else {
      this.build(element);
    }
  },
  
  build: function(element) {
    var normal = this.getNormalClass(element);
    var hover = this.getHoverClass(normal);
    
    if (this.options.cssUtil) {
      normal = this.options.cssUtil.joinClassNames(normal);
      hover = this.options.cssUtil.joinClassNames(hover);    
    }
    
    this.setHoverEvent(element, normal, hover);
  },

  setHoverEvent: function(element, normal, hover) {
    Event.observe(element, "mouseout", this.toggle(normal).bindAsEventListener(this));
    Event.observe(element, "mouseover", this.toggle(hover).bindAsEventListener(this));
  },
  
  toggle: function(className) {
    return function(event) {
      var src = Event.element(event);
      src.className = className;
    }
  },
  
  getNormalClass: function(element) {
    
    var className = (this.options.defaultClass || element.className);
    return (className || '');
  },
  
  getHoverClass: function(defaultClass) {

    var className = this.options.hoverClass;
    
    if (!className) {
      className = defaultClass.split(' ').collect(function(c) {
        return c + 'Hover';
      }).join(' ');
    }  
    
     return className;
  }
}


/**
 * DateUtil
 */
var DateUtil = {

  dayOfWeek: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],

  months: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],

  daysOfMonth: [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31],

  isLeapYear: function(year) {
    if (((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0))
      return true;
    return false;
  }, 

  nextDate: function(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1);
  },

  previousDate: function(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() - 1);
  },
  
  getLastDate: function(year, month) {
    var last = this.daysOfMonth[month];
    if ((month == 1) && this.isLeapYear(year)) {
      return last + 1;
    }
    return new Date(year, month, last);
  },
  
  getFirstDate: function(year, month) {
    return new Date(year, month, 1);
  },

  toDateString: function(date) {
    return date.toDateString();
  },
  
  toLocaleDateString: function(date) {
    return date.toLocaleDateString();
  },
  
  simpleFormat: function(formatStr) {
    return function(date) {
      var formated = formatStr.replace(/M+/g, date.getMonth() + 1);
      formated = formated.replace(/d+/g, date.getDate());
      formated = formated.replace(/y{4}/g, date.getFullYear());
      formated = formated.replace(/y{1,3}/g, new String(date.getFullYear()).substr(2));
      formated = formated.replace(/E+/g, DateUtil.dayOfWeek[date.getDay()]);
      
      return formated;
    }
  }
}
