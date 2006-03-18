/**
------------
Notify.js
------------
	Written by: Greg Militello <gmilitello@dyrectmedia.com>
				thinkof.net
	
	Loosely based on code from:
		Lokesh Dhakar on his Lightbox project.
			http://huddletogether.com
			http://huddletogether.com/projects/lightbox/
		script.aculo.us javascript effects library
			http://script.aculo.us

------------
License information (BSD lisence based):
------------
		Copyright (c) 2006, Greg Militello
		All rights reserved.

		Redistribution and use in source and binary forms, with or without modification, 
		are permitted provided that the following conditions are met:

		    * Redistributions of source code must retain the above copyright notice, 
				this list of conditions and the following disclaimer.
		    * Redistributions in binary form must reproduce the above copyright notice, 
				this list of conditions and the following disclaimer in the 
				documentation and/or other materials provided with the distribution.
		    * Neither the name of the thinkof.net nor the names of its contributors 
				may be used to endorse or promote products derived from this software 
				without specific prior written permission.

		THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
		ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
		WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
		IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
		INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
		BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
		OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
		WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
		ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
		POSSIBILITY OF SUCH DAMAGE.

------------
Sample usage:
------------
		<script language="javascript">
			new Notify.Alert ('The task you wanted to complete has failed, or something.', {messagecolor: "#ff9999", outEffect: "Effect.BlindUp", inEffect: "Effect.BlindDown", autoHide: 'true'});
		</script>
			OR
		<a href="#" onclick="new Notify.Alert ('You clicked me!', {autoHide: 'false'}); return false;">Click me</a><br/>
			OR
		<a href="http://google.com" onclick="new Notify.Confirm ('Go to <em>google</em>?<br/>Cause you can not comeback.', this, {outEffect: 'Effect.DropOut'}); return false;">Google.com</a>
*/
var Notify = {}

//
// OBJECT Notify.Base
// Creates a set of functions for the rest of the notify LIB to inherit from.
// Defines a method for option switching 
//		(Code adapted from [http://script.aculo.us/]'s Effect.Base)
//
Notify.Base = function() {};
Notify.Base.prototype = {
	//
	// PUBLIC METHOD Notify.Base.getVersion()
	// Returns the version of this object
	//
	getVersion: function () {
		return ('v0.8.3');
	},
	//
	// PRIVATE METHOD Notify.Base.hide()
	// Called when hiding 
	//
	hide: function(name) {
		this.options.outEffect(name);
	},
	//
	// PRIVATE METHOD Notify.Base.show()
	// Called when showing 
	//
	show: function(name) {
		this.options.inEffect(name);
	},
	//
	// PRIVATE METHOD Notify.Base.getPageSize
	// Gets the size of the page so the overlay can cover it all.
	//
	// This method's code is from Lokesh Dhakar, just packaged into a JS object
	//
	getWindowHeight: function(){
		var windowHeight;
		if (self.innerHeight) {	// all except Explorer
			windowHeight = self.innerHeight;
		} else if (document.documentElement && document.documentElement.clientHeight) { // Explorer 6 Strict Mode
			windowHeight = document.documentElement.clientHeight;
		} else if (document.body) { // other Explorers
			windowHeight = document.body.clientHeight;
		}	
		return windowHeight;
	},
	//
	// PRIVATE METHOD Notify.Base.setOptions()
	// Parse options into usable values
	//
	setOptions: function(options) {
		this.options = Object.extend({
		}, options || {});
	},
	//
	// PRIVATE METHOD Notify.Base.start()
	// Actions to kickoff to once this has started
	//
	start: function(options) {
		this.arrayPageScroll = this.getPageScroll();
		this.objBody = document.getElementsByTagName("body").item(0);
		this.setOptions(options || {});
	},
	//
	// PRIVATE METHOD Notify.Base.getPageScroll()
	// Returns array with x,y page scroll values.
	// Core code from - quirksmode.org
	//
	getPageScroll: function (){
		var yScroll;
		if (self.pageYOffset) {
			yScroll = self.pageYOffset;
		} else if (document.documentElement && document.documentElement.scrollTop){	 // Explorer 6 Strict
			yScroll = document.documentElement.scrollTop;
		} else if (document.body) {// all other Explorers
			yScroll = document.body.scrollTop;
		}
		return yScroll;
	}
}

//
// OBJECT Notify.Alert
// Creates an alert box, similar to a javascript alert, except that it is 
// customizable, and stylable.
//
// Example usage: <a href="#" onClick="Notify.Alert ('I have been clicked')">Click me</a>
//
Notify.Alert = Class.create();
Notify.Alert.prototype = Object.extend(new Notify.Base(), {
	
	//
	// PRIVATE METHOD Notify.Alert.initialize()
	// Class setup
	//
	initialize: function(message) {
		this.message = message;
	    var options = Object.extend({
			messagecolor:		"#ffff99",
			inEffect:			function (el) { new Element.show(el) },
			outEffect:			function (el) { new Element.hide(el) },
			idPrefix:			"Notify",
			autoHide:			"false",
			closeText:			"Close"
		}, arguments[1] || {});
		this.start(options);
		this.draw();
	},
	//
	// PRIVATE METHOD Notify.Alert.draw()
	// Draw the box
	//
	draw: function() {
		var objAlertOverlay = document.createElement("div");
		objAlertOverlay.setAttribute('id', this.options.idPrefix + 'AlertOverlay');
		objAlertOverlay.style.height = (Element.getHeight(this.objBody) + 'px');
		notifyOutEffect = this.options.outEffect;
		notifyIdPrefix = this.options.idPrefix;
		objAlertOverlay.style.display = 'none';
		this.objBody.insertBefore(objAlertOverlay, this.objBody.firstChild);
		
		var objAlertWrap = document.createElement("div");
		objAlertWrap.setAttribute('id', this.options.idPrefix + 'AlertWrap');	
		objAlertOverlay.appendChild(objAlertWrap);

		var objAlert = document.createElement("div");
		objAlert.setAttribute('id', this.options.idPrefix + 'Alert');
		objAlertWrap.appendChild(objAlert);

		var objLink = document.createElement("a");
		objLink.setAttribute('href','#');
		objLink.setAttribute('title', this.options.closeText);
		Event.observe(objAlertOverlay, 'click', function () { this.options.outEffect(objAlertOverlay); return false; }.bind(this));
		var objLinkText = document.createTextNode(this.options.closeText);
		objLink.setAttribute('class','close');
		objLink.appendChild(objLinkText);
		objAlertWrap.appendChild(objLink);

		var objAlertNotice = document.createElement("div");
		objAlertNotice.setAttribute('class','alert');
		objAlertNotice.style.backgroundColor = this.options.messagecolor;
		objAlertNotice.innerHTML = this.message;
		objAlert.appendChild(objAlertNotice);

		this.show(this.options.idPrefix+'AlertOverlay');
		if (this.options.autoHide == 'true') {
			this.hide(this.options.idPrefix+'AlertOverlay');
		}
		var top = (this.arrayPageScroll + (this.getWindowHeight() - (Element.getHeight(objAlertNotice)*2.5)) / 2);
		objAlertWrap.style.marginTop = top + "px";
	}
});

//
// OBJECT Notify.Confirm
// Creates a confirm box, similar to a javascript confirm, except that it is 
// customizable, and stylable.
//
// Example usage: <a href="#" onClick="Notify.Confirm ('Are you sure??', 'http://gohere.com')">Click me</a>
// Or: 			  <a href="http://gohere.com" onClick="Notify.Confirm ('Are you sure??', this)">Click me</a>
// Or: 			  <form action="http://gohere.com" onClick="Notify.Confirm ('Are you sure??', this)">Click me</a>
//
Notify.Confirm = Class.create();
Object.extend(Object.extend(Notify.Confirm.prototype, Notify.Base.prototype), {
	
	//
	// PRIVATE METHOD Notify.Confirm.initialize()
	// Class setup
	//
	initialize: function(message, destination) {
		this.message = message;
		this.destination = destination;
	    var options = Object.extend({
			messagecolor:		"#ffff99",
			inEffect:			function (el) { new Element.show(el) },
			outEffect:			function (el) { new Element.hide(el) },
			idPrefix:			"Notify",
			confirmText:		"Confirm",
			cancelText:			"Cancel"
		}, arguments[2] || {});
		this.start(options);
		this.setDestination();
		this.draw();
	},
	
	//
	// PRIVATE METHOD Notify.Confirm.setDestination()
	// Deturmines if the 'destination' parameter is a string, form element, or anchor element.  
	//		Based on that knowledge, it deturmines the behavior of the confirmation button.
	//
	setDestination: function () {
		if (this.destination.tagName == 'FORM') {
			this.isForm = true;
			this.destination = this.destination;
		} else if (this.destination.tagName == 'A') {
			this.destination = this.destination.href;
			this.isForm = false;
		} else if (typeof this.destination == 'string'){
			this.isForm = false;
			this.destination = this.destination;
		} else {
			this.destination = this.destination;
			this.isForm = false;
		}
	},
	
	//
	// PRIVATE METHOD Notify.Confirm.draw()
	// Draw the box
	//
	draw: function() {
		var objBody = document.getElementsByTagName("body").item(0);

		var objConfirmOverlay = document.createElement("div");
		objConfirmOverlay.setAttribute('id', this.options.idPrefix + 'ConfirmOverlay');
		objConfirmOverlay.style.display = 'none';
		objConfirmOverlay.style.height = (Element.getHeight(this.objBody) + 'px');
		objBody.insertBefore(objConfirmOverlay, objBody.firstChild);

		var objConfirmWrap = document.createElement("div");
		objConfirmWrap.setAttribute('id', this.options.idPrefix + 'ConfirmWrap');	
		objConfirmOverlay.appendChild(objConfirmWrap);

		var objConfirm = document.createElement("div");
		objConfirm.setAttribute('id', this.options.idPrefix + 'Confirm');
		objConfirmWrap.appendChild(objConfirm);

		var objConfirmNotice = document.createElement("div");
		objConfirmNotice.setAttribute('class','confirm');
		objConfirmNotice.style.backgroundColor = this.options.messagecolor;
		objConfirmNotice.innerHTML = this.message;
		
		objConfirm.appendChild(objConfirmNotice);
		
		var objLink = document.createElement("a");
		objLink.setAttribute('href','#');
		notifyOutEffect = this.options.outEffect;
		notifyIdPrefix = this.options.idPrefix;
		Event.observe(objConfirmOverlay, 'click', function () { this.options.outEffect(objConfirmOverlay); return false; }.bind(this));
		objLink.setAttribute('title',this.options.cancelText);
		objLink.setAttribute('class','cancel');

		var objLinkText = document.createTextNode(this.options.cancelText);
		objLink.appendChild(objLinkText);
		objConfirmWrap.appendChild(objLink);
		
		var objLink = document.createElement("a");
		objLink.setAttribute('href','#');
		objLink.setAttribute('title',this.options.confirmText);
		objLink.setAttribute('class','confirm');
		if (this.isForm) {
			Event.observe(objLink, 'click', function () { this.destination.submit(); return false; }.bind(this));
		} else {
			Event.observe(objLink, 'click', function () { window.location=this.destination; return false; }.bind(this));
		}
		var objLinkText = document.createTextNode(this.options.confirmText);
		objLink.appendChild(objLinkText);
		objConfirmWrap.appendChild(objLink);
		
		this.show(this.options.idPrefix +'ConfirmOverlay');
		var top = (this.arrayPageScroll + (this.getWindowHeight() - (Element.getHeight(objConfirmNotice)*2.5)) / 2);
		objConfirmWrap.style.marginTop = top + "px";
	}
});
