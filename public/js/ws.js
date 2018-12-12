$(function () {
	function ping() {
        ws.send('__ping__');
        tm = setTimeout(function () {

           /// ---connection closed ///


	    }, 5000);
	}

	function pong() {
    		clearTimeout(tm);
	}

	var ws = new WebSocket('ws://localhost:9090/ws');
	ws.onopen = function () {
        log('Connection opened');
		setInterval(ping, 4500);
		ws.send('start');
	}

      var log = function (text) {
        $('#log').val( $('#log').val() + text + "\n");
      };
  
      ws.onmessage = function (event) {
	var msg = JSON.parse(event.data);
	switch(msg.type) {
		case "image":
			if(msg.hide) {
				var image = document.getElementById(msg.elementid);
				$(image).fadeOut();
				$(msg.elementid).hide();
			};
			if(msg.show) {
				if (msg.link) {
					$(msg.elementid).attr('src', msg.link).show();
				} else {
					if (msg.format) {
						var image = document.getElementById(msg.elementid);
	                			image.src = 'data:image/'+ msg.format +';base64,'+ msg.image;
					} else {
						var image = document.getElementById(msg.elementid);
						image.src = 'data:image/png;base64,'+ msg.image;
					}
				}
		                if (msg.log) {
                                        log(msg.log);
                                }
			}
      			break;
			
		case "text":
                        if(msg.in) {
				$(msg.elementid).html(msg.text).show();
				if (msg.log) {
					log(msg.log);
				}
				
                        }
			if(msg.out) {
				$(msg.elementid).hide();
			}
                        break;
		case "reload":
			location.reload();
			break;
		case "container":
			if(msg.in) {
				$(msg.elementid).show();
				$("#info-right").html(msg.text);
			}
                case "search":
                        if(msg.in) {
				$('.typeahead').typeahead({
				    highlight: true,
				},
				{
				name: 'Search',
  				display: 'value',
				limit: 400,
				 source: function(query, syncResults, asyncResults) {
				    	$.get('/search?term=' + query, function(data) {
      					asyncResults(data);
    					});
  				}
				});

				$('.typeahead').on('typeahead:selected', function (e, datum) {
					var url = msg.webhook + datum.id + "?noaction=1";
					$('.fake-hidden').val( url );
					$.ajax ({
						url: url,
						type: 'POST',
						crossDomain: true
					});
				});			

                        }
			if(msg.out) {
				$('.typeahead').typeahead('val','');
			}
		case "template":
                        if(msg.show) {
				if (msg.file) {
					var file = "/templates/" + msg.file;
					$(msg.elementid).load( file );
					//log(msg.log).delay(1);
				}
                        }
		case "layout":
			if(msg.show) {
                                if (msg.data) {
					var Base64={_keyStr:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=",encode:function(e){var t="";var n,r,i,s,o,u,a;var f=0;e=Base64._utf8_encode(e);while(f<e.length){n=e.charCodeAt(f++);r=e.charCodeAt(f++);i=e.charCodeAt(f++);s=n>>2;o=(n&3)<<4|r>>4;u=(r&15)<<2|i>>6;a=i&63;if(isNaN(r)){u=a=64}else if(isNaN(i)){a=64}t=t+this._keyStr.charAt(s)+this._keyStr.charAt(o)+this._keyStr.charAt(u)+this._keyStr.charAt(a)}return t},decode:function(e){var t="";var n,r,i;var s,o,u,a;var f=0;e=e.replace(/[^A-Za-z0-9+/=]/g,"");while(f<e.length){s=this._keyStr.indexOf(e.charAt(f++));o=this._keyStr.indexOf(e.charAt(f++));u=this._keyStr.indexOf(e.charAt(f++));a=this._keyStr.indexOf(e.charAt(f++));n=s<<2|o>>4;r=(o&15)<<4|u>>2;i=(u&3)<<6|a;t=t+String.fromCharCode(n);if(u!=64){t=t+String.fromCharCode(r)}if(a!=64){t=t+String.fromCharCode(i)}}t=Base64._utf8_decode(t);return t},_utf8_encode:function(e){e=e.replace(/rn/g,"n");var t="";for(var n=0;n<e.length;n++){var r=e.charCodeAt(n);if(r<128){t+=String.fromCharCode(r)}else if(r>127&&r<2048){t+=String.fromCharCode(r>>6|192);t+=String.fromCharCode(r&63|128)}else{t+=String.fromCharCode(r>>12|224);t+=String.fromCharCode(r>>6&63|128);t+=String.fromCharCode(r&63|128)}}return t},_utf8_decode:function(e){var t="";var n=0;var r=c1=c2=0;while(n<e.length){r=e.charCodeAt(n);if(r<128){t+=String.fromCharCode(r);n++}else if(r>191&&r<224){c2=e.charCodeAt(n+1);t+=String.fromCharCode((r&31)<<6|c2&63);n+=2}else{c2=e.charCodeAt(n+1);c3=e.charCodeAt(n+2);t+=String.fromCharCode((r&15)<<12|(c2&63)<<6|c3&63);n+=3}}return t}}

					var layout = Base64.decode(msg.data);
					$(msg.elementid).html('').append(layout);
                                }
                        }
		case "pong":
			pong();
			return;
	}	
//	if (msg == '__pong__') {
//		console.log(msg);
//        	pong();
//        	return;
//    	}

//	if(res.msg){
//		console.log(msg);		
//		var res = JSON.parse(msg);
//       	log(res.msg);
//		return;
//	}

//	if(res.image.length){
//       	var res = JSON.parse(image.data);
//		var image = document.createElement('img');
//		image.src = 'data:image/png;base64,'+ res.image;
//		document.body.appendChild(image);
//	}
      };

    $('#msg').keydown(function (e) {
        if (e.keyCode == 13 && $('#msg').val()) {
            ws.send($('#msg').val());
            $('#msg').val('');
        }
	});
});

