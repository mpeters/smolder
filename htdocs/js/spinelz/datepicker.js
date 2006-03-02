// Copyright (c) 2005 Tomoaki Kinoshita (http://script.spinelz.org/)
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

var DatePicker = Class.create();
DatePicker.className = {
  container: 'datepicker',
  header: 'header',
  preYears: 'pre_years',
  nextYears: 'next_years',
  years: 'years',
  mark: 'mark',
  markHover: 'markHover',
  calendar: 'calendar',
  date: 'date',
  dateHover: 'dateHover',
  holiday: 'holiday'
}
DatePicker.mark = {
  preYear: '<<',
  preMonth: '<',
  nextYear: '>>',
  nextMonth: '>'
}
DatePicker.week = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
DatePicker.month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
DatePicker.daysOfMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
DatePicker.prototype = {
  
  initialize: function(element, target, trigger) {
    this.element = $(element);
    this.target = $(target);
    this.date = new Date();

    var options = Object.extend({
      month: this.date.getMonth() + 1,
      date: this.date.getDate(),
      year: this.date.getFullYear(),
      format: DateFormat.toLocaleDateString
    }, arguments[3] || {});
    
    this.format = options.format;
    
    this.date.setMonth(options.month - 1);
    this.date.setDate(options.date);
    this.date.setFullYear(options.year);
    
    this.calendar = this.build();
    this.element.appendChild(this.calendar);
    
    this.doclistener = this.hide.bindAsEventListener(this);
    Event.observe($(trigger), "click", this.show.bindAsEventListener(this));
    this.hide();
  },
  
  build: function() {
    var node = 
      Builder.node(
        'DIV', 
        {className: DatePicker.className.container},
        [
          this.buildHeader(),
          this.buildCalendar()
        ]);
    
    return node;
  },
  
  buildHeader: function() {
    var headerNodes = new Array();
    
    var nodes = this.multiBuild(
                  'DIV', 
                  [DatePicker.mark.preYear, DatePicker.mark.preMonth], 
                  DatePicker.className.mark, 
                  DatePicker.className.markHover,
                  this.changeCalendar());
    headerNodes.push(Builder.node('DIV', {className: DatePicker.className.preYears}, nodes));
    
    nodes = this.multiBuild('SPAN', [this.getMonth(), this.date.getFullYear()]);
    headerNodes.push(Builder.node('DIV', {className: DatePicker.className.years}, nodes));  
    
    nodes = this.multiBuild(
              'DIV', 
              [DatePicker.mark.nextMonth, DatePicker.mark.nextYear], 
              DatePicker.className.mark, 
              DatePicker.className.markHover,
              this.changeCalendar());
    headerNodes.push(Builder.node('DIV', {className: DatePicker.className.nextYears}, nodes));
    
    return Builder.node('DIV', {className: DatePicker.className.header}, headerNodes);
  },
  
  multiBuild: function(tagType, params, className, hoverClass, clickEvent) {
    var children = new Array();
    for (var i = 0; i < params.length; i++) {
      var node;
      
      if (className)
        node = Builder.node(tagType, {className: className}, [params[i]]);
      else
        node = Builder.node(tagType, [params[i]]);
      
      if (hoverClass)
        this.setHoverEvent(node, className, hoverClass);
      
      if (clickEvent)
        Event.observe(node, "click", clickEvent.bindAsEventListener(this));
        
      children.push(node);
    }
    
    return children;
  },
  
  buildCalendar: function() {
    var table = Builder.node('TABLE', [
                  Builder.node(
                    'TBODY',
                    [
                      this.buildTableHeader(),
                      this.buildTableData()
                    ])
                ]);
                  
    return Builder.node('DIV', {className: DatePicker.className.calendar}, [table]);
  },
  
  buildTableHeader: function() {
    var weekArray = new Array();
    for (var i = 0; i < DatePicker.week.length; i++) {
      weekArray.push(Builder.node('TH', DatePicker.week[i]));
    }
    
    return Builder.node('TR', weekArray);
  },
  
  buildTableData: function() {
    var length = DatePicker.week.length * 5;
    var firstDay = this.getFirstDay();
    var lastDate = this.getLastDate();
    var trs = new Array();
    var tds = new Array();
    
    for (var i = 0, day = 1; i <= length; i++) {
      if ((i < firstDay) || day > lastDate) {
        tds.push(Builder.node('TD'));
      
      } else {
        var className;
        if ((i % 7 == 0) || ((i+1) % 7 == 0))
          className = DatePicker.className.holiday;
        else
          className = DatePicker.className.date;
          
        node = Builder.node('TD', {className: className}, [day]);
        this.setHoverEvent(node, className, DatePicker.className.dateHover);
        Event.observe(node, "click", this.selectDate.bindAsEventListener(this));
        tds.push(node);
        day++;
      }
      
      if ((i + 1) % 7 == 0) {
        trs.push(Builder.node('TR', tds));
        tds = new Array();
      }
    }
    
    return trs;
  },
  
  refresh: function() {
    Element.remove(this.calendar);
    this.calendar = this.build();
    this.element.appendChild(this.calendar);
  },
  
  getLastDate: function() {
    var days = DatePicker.daysOfMonth[this.date.getMonth()];
    if ((this.date.getMonth() != 2) || !this.isLeapYear())
      return days;
    return days + 1;
  },
  
  isLeapYear: function() {
    var year = this.date.getFullYear();
    if (((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0))
      return true;
    return false;
  }, 
  
  getFirstDay: function() {
    var date = new Date(this.getMonth() + ' 1, ' + this.date.getFullYear());
    return date.getDay();
  },
  
  getMonth: function() {
    return  DatePicker.month[this.date.getMonth()];
  },
  
  setHoverEvent: function(element, normal, hover) {
    Event.observe(element, "mouseout", this.toggleHover(normal).bindAsEventListener(this));
    Event.observe(element, "mouseover", this.toggleHover(hover).bindAsEventListener(this));
  },
  
  toggleHover: function(className) {
    return function(event) {
      var src = Event.element(event);
      src.className = className;
    }
  },
  
  changeCalendar: function() {
    return function(event) {
      var value = this.getTextValue(Event.element(event)).nodeValue;
      
      switch (value) {
        case DatePicker.mark.preYear: 
          this.date.setFullYear(this.date.getFullYear() - 1);
          break;
        
        case DatePicker.mark.preMonth: 
          var pre = this.date.getMonth() - 1;
          if (pre < 0) {
            pre = 11;
            this.date.setFullYear(this.date.getFullYear() - 1);
          }
          this.date.setMonth(pre);
          break;
        
        case DatePicker.mark.nextYear: 
          this.date.setFullYear(this.date.getFullYear() + 1);
          break;
        
        case DatePicker.mark.nextMonth: 
          var next = this.date.getMonth() + 1;
          if (next > 11) {
            next = 0;
            this.date.setFullYear(this.date.getFullYear() + 1);
          }
          this.date.setMonth(next);
          break;
      }
      
      this.refresh();
    }
  },
  
  selectDate: function(event) {
    var src = Event.element(event);
    var text = this.getTextValue(src);
    
    this.date.setDate(text.nodeValue);
    
    var value = this.format(this.date);
      
    this.target.value = value;
    this.hide();
    src.className = DatePicker.className.date;
  },
  
  getTextValue: function(element) {
    return $A(element.childNodes).detect(function(child) {
      return (child.nodeType == 3);
    });
  },
  
  show: function(event) {
    Element.show(this.calendar);
    Event.observe(document, "click", this.doclistener);
    Event.stop(event);
  },
  
  hide: function() {
    Event.stopObserving(document, "click", this.doclistener);
    Element.hide(this.calendar);
  }
}


var DateFormat = {
  
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
      formated = formated.replace(/E+/g, DatePicker.week[date.getDay()]);
      
      return formated;
    }
  }
}
