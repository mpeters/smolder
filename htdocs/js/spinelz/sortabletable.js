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

var SortableTable = Class.create();
SortableTable.prototype = {
  
  initialize:  function(element) {
    this.element = $(element);
    var options = Object.extend({
      ascImg: false,
      descImg: false,
      sortType: false
    }, arguments[1] || {});
    
    this.ascImg = options.ascImg ? options.ascImg : 'img/down.gif';
    this.descImg = options.descImg ? options.descImg : 'img/up.gif';
    this.sortType = options.sortType;
    
    this.currentOrder = 'default';
    this.defaultOrder = new Array();
    for (var i = 1; i < this.element.rows.length; i++) {
      this.defaultOrder[i - 1] = this.element.rows[i];
    }
    
    this.addEvent();
  },
  
  addEvent: function() {
    var rows = this.element.rows[0];
    if (!rows) return;
    
    for (var i = 0; i < rows.cells.length; i++) {
      rows.cells[i].style.cursor = 'pointer';
      Event.observe(rows.cells[i], 'click', this.sortTable.bindAsEventListener(this));
    }
  },
  
  getValue: function(cell) {
    var value = $A(cell.childNodes).detect(function(child) {
      return (child.nodeType == 3);
    });
    
    if (value) return value.nodeValue;
    else return '';
  },
  
  sortTable: function(event) {
    var cell = Event.element(event);
    if (cell.tagName == 'IMG') {
      cell = cell.parentNode;  
    }
    
    var tmpColumn = cell.cellIndex;
    if (this.targetColumn != tmpColumn) {
      this.currentOrder = 'default';
    }
    this.targetColumn = tmpColumn;
    
    var newRows = new Array();
    for (var i = 1; i < this.element.rows.length; i++) {
      newRows[i - 1] = this.element.rows[i];
    }
    if (newRows.length < 1) return;
        
    if (this.currentOrder == 'default') {
      newRows.sort(this.getSortFunc());
      this.currentOrder = 'asc';
    } else if (this.currentOrder == 'asc') {
      newRows = newRows.reverse();
      this.currentOrder = 'desc';
    } else if (this.currentOrder == 'desc') {
      newRows = this.defaultOrder;
      this.currentOrder = 'default';
    }
    
    for (var i = 0; i < newRows.length; i++) {
      this.element.tBodies[0].appendChild(newRows[i]);
    }
    
    this.mark(cell);
  },
  
  mark: function(cell) {
    var row = this.element.rows[0];
    for (var i = 0; i < row.cells.length; i++) {
      var child = row.cells[i].lastChild;
      if (child && (child.tagName == 'IMG')) {
        row.cells[i].removeChild(child);
      }
    }
    
    var imgFile;
    if (this.currentOrder == 'asc') imgFile = this.ascImg;
    else if (this.currentOrder == 'desc') imgFile = this.descImg;
    
    if (imgFile)
      cell.appendChild(Builder.node('IMG', {src: imgFile, alt: 'sortImg'}));
  },

  getSortFunc: function() {
    if (!this.sortType || !this.sortType[this.targetColumn])
      return SortFunction.string(this);
    
    var type = this.getSortType();
    
    if (!this.sortType || !type) {
      return SortFunction.string(this);
    } else if (type == SortFunction.numeric) {
      return SortFunction.number(this);
    } 
    
    return SortFunction.date(this);
  },
  
  getSortType: function() {
    return this.sortType[this.targetColumn];
  }
}

var SortFunction = Class.create();
SortFunction = {
  string: 'string',
  numeric: 'numeric',
  mmddyyyy: 'mmddyyyy',
  mmddyy: 'mmddyy',
  yyyymmdd: 'yyyymmdd',
  yymmdd: 'yymmdd',
  
  date: function(grid) {
    return function(fst, snd) {
      var aValue = grid.getValue(fst.cells[grid.targetColumn]);
      var bValue = grid.getValue(snd.cells[grid.targetColumn]);
      var date1, date2;
      
      var date1 = SortFunction.getDateString(aValue, grid.getSortType());
      var date2 = SortFunction.getDateString(bValue, grid.getSortType());
      
      if (date1 == date2) return 0;
      if (date1 < date2) return -1;
      
      return 1;
    }
  },
  
  number: function(grid) {
    return function(fst, snd) {
      var aValue = parseFloat(grid.getValue(fst.cells[grid.targetColumn]));
      if (isNaN(aValue)) aValue = 0;
      var bValue = parseFloat(grid.getValue(snd.cells[grid.targetColumn])); 
      if (isNaN(bValue)) bValue = 0;
      
      return aValue - bValue;
    }
  },
  
  string: function(grid) {
    return function(fst, snd) {
      var aValue = grid.getValue(fst.cells[grid.targetColumn]);
      var bValue = grid.getValue(snd.cells[grid.targetColumn]);
      if (aValue == bValue) return 0;
      if (aValue < bValue) return -1;
      return 1;
    }
  },
  
  getDateString: function(date, type) {
    var array = date.split('/');

    if ((type == SortFunction.mmddyyyy) ||
        (type == SortFunction.mmddyy)) {
      var newArray = new Array();
      newArray.push(array[2]);
      newArray.push(array[0]);
      newArray.push(array[1]);
    } else {
      newArray = array;
    }
    
    return newArray.join();
  }
}

