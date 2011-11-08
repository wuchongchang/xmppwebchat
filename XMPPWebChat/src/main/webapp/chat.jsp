<!--
  Copyright (C) 2011  Adam Hocek. Contact: ahocek@gmail.com, Udaya K Ghattamaneni. 
  Contact: ghattamaneni.uday@gmail.com 
  
  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.
  
  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.
  
  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
-->
<%@ page language="java" contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8"%>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<%@ page import="edu.maristit.xmppwebchat.*,java.util.*" %>
<%@ page import="org.cometd.bayeux.server.BayeuxServer,org.cometd.server.*" %>
<html>
    <head>
        <title>Chat</title>
        <link rel="stylesheet" type="text/css" href="css/jquery.autocomplete.css" />
        <link type="text/css" href="css/redmond/jquery-ui-1.8.14.custom.css" rel="stylesheet" />
 	<script type="text/javascript" src="jquery/jquery-1.6.2.js"></script>
        <script type="text/javascript" src="jquery/json2.js"></script>
        <script type="text/javascript" src="org/cometd.js"></script>
        <script type="text/javascript" src="jquery/jquery.cometd.js"></script>
        <script type="text/javascript" src="js/jquery-ui-1.8.14.custom.min.js"></script>
        <script type='text/javascript' src='js/jquery.autocomplete.js'></script>
        <script type='text/javascript' src='js/lib/jquery.bgiframe.min.js'></script>
        <script type='text/javascript' src='js/lib/jquery.ajaxQueue.js'></script>
        <script type="text/javascript">
            $(function() {
                var $tabs =$( "#tabs" ).tabs();
		
                $( "#tabs" ).tabs( "option", "tabTemplate", "<li><a class='chatAlert' id='tag-\#{href}' href='\#{href}'>\#{label}</a> <span class='ui-icon ui-icon-close'>Remove Tab</span></li>" );
		
                $( "#tabs span.ui-icon-close" ).live( "click", function() {
                    var index = $( "li", $tabs ).index( $( this ).parent() );
                    $tabs.tabs( "remove", index );
                });

                $( "#tabs" ).bind('tabsselect',
                function(event, ui) {
                    if(ui.index>0){
                        var i = ui.tab.href.substr(ui.tab.href.length-1);
                        //alert(i); 
                        //focusText(i);
                        //alert(ui.tab.className);
                        ui.tab.className="";
                        //alert($('#tabs').getTabs());
                    }
                });
            });

        </script>

        <script type="text/javascript">
	
            <%
        //System.out.println( "Evaluating date now" );
        //Date date = new Date();

            String userName = request.getParameter("userName");
            String password = request.getParameter("password");
            String domain = request.getParameter("domain");
            userName = userName.trim().toLowerCase();
            domain = domain.trim().toLowerCase();
            if (!userName.contains("@")) {
                userName = userName + "@" + domain;
            }
            out.println("var chatRoomName = \"" + userName + "\";");
            out.println("var domainName = \"" + domain + "\";");
            org.cometd.bayeux.server.BayeuxServer b = (BayeuxServer) getServletContext().getAttribute(BayeuxServer.ATTRIBUTE);

            List<edu.maristit.xmppwebchat.XmppManager> XMPPConnections = null;
            if (session.getAttribute("xmppConns") != null) {
                XMPPConnections = (List<edu.maristit.xmppwebchat.XmppManager>) session.getAttribute("xmppConns");
            }
            if (XMPPConnections == null) {
                XMPPConnections = new ArrayList<edu.maristit.xmppwebchat.XmppManager>();
            }
            for (int i = 0; i < XMPPConnections.size(); i++) {
                edu.maristit.xmppwebchat.XmppManager xmppManagerTemp = XMPPConnections.get(i);
                try {
                    if (xmppManagerTemp.getUserName().equalsIgnoreCase(userName)) {
                        xmppManagerTemp.destroy();
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }

            }
            if (domain == null || domain.toString().equals("")) {
                domain = "";
            }
            XmppManager xmppManager1 = null;
            if (domain.toString().equalsIgnoreCase("gmail.com")) {
                xmppManager1 = new XmppManager(domain, b);
            } else {
                xmppManager1 = new XmppManager(domain, 5222, b);
            }

            try {
                if (domain.toString().equalsIgnoreCase("chat.facebook.com")) {
                    xmppManager1.init(request.getParameter("userName").trim().toLowerCase(), password);
                    xmppManager1.setStatus(true, "");
                } else {
                    xmppManager1.init(userName, password);
                    xmppManager1.setStatus(true, "");
                }


                XMPPConnections.add(xmppManager1);
                session.setAttribute("xmppConns", XMPPConnections);

                out.println("var userName='" + userName + "';");
            } catch (Exception e) {
                String redirectURL = "error.jsp";
                e.printStackTrace();
                response.sendRedirect(redirectURL + "?msg=Login Failed!!");
            }

            %>
            var counter = 1;
            /************/
            //dojo.require("dojox.cometd");
            var config = {
                contextPath: '${pageContext.request.contextPath}'
            };
           // var cometd = dojox.cometd;
	var cometd = $.cometd;
            var _connected = false;
            function _connectionSucceeded()
            {
                var d=new Date();
		$('#body').innerHTML += "<br/>Connected At:"+d;
            }

            function _connectionBroken()
            {
                var d=new Date();
               $('#body').innerHTML  += "<br/>Connection Broken At:"+d;
                logoff();
            }

            function _metaConnect(message)
            {
                var wasConnected = _connected;
                _connected = message.successful === true;
                if (!wasConnected && _connected)
                {
                    _connectionSucceeded();
                }
                else if (wasConnected && !_connected)
                {
                    _connectionBroken();
                }
            }
            /**/
            // Disconnect when the page unloads
            //dojo.addOnUnload(function()
	   $(window).unload(function()
            {
                logoff();
                cometd.disconnect();
                //alert("unloading");
            });

            var cometURL = location.protocol + "//" + location.host + config.contextPath + "/cometd";
            cometd.configure({
                url: cometURL,
                logLevel: 'debug',
                backoffIncrement: 1000,
                maxBackoff: 60000
            });

            cometd.addListener('/meta/connect', _metaConnect);
            cometd.handshake();

            
            /*************/
            function logoff(){
                var userNameJson = {logout:'true'};
                cometd.publish("/"+chatRoomName, userNameJson);
                //hub.unsubscribe(chatRoomName);
                cometd.disconnect();
                alert("Logging out "+chatRoomName);
                window.location = "logout.jsp?userName="+userName;
            }



            function getBuddies()
            {
                cometd.publish("/"+chatRoomName, {request:'USERS'});
                //alert("publish");
            }
            function chatUpdated(data) {
                //alert("data:"+data.data);
                data=data.data;
                if (!!data.chat) {
                    //	chatMessagesBox.value += "\n" + data.user + ": " + data.chat;
                    openChatTab(data.user,false,data.displayName);
                    updateChat(data.user,data.user,data.chat);
                } else if(!!data.confChat) {
                    //alert("confchat");
                    if(!document.getElementById('GROUPCHATINDEX_'+data.roomName)){
                        addChatRoom(data.roomName,data.server);
                    }
                    openGroupChatTab(data.roomName,false);
                    updateConfChat(data.fromUser,data.roomName,data.confChat);

                } else if (!!data.buddyStatus) {
                    //	chatMessagesBox.value += "\n>>>" + data.user+"<-changed to->"+data.buddyStatus;
                    eval("buddyStatus="+data.buddyStatus);
                    var x = document.getElementsByName('USER_STATUS_'+buddyStatus.email)
                    if(x.length==0) 
                        addAutomaticUser(buddyStatus.email);
                    for(var y=0;y<x.length;y++){
                        var img = x[y].childNodes[0];
			
                        if(buddyStatus.presence.indexOf("dnd")!=-1){
                            img.src="images/busy.ico";
                        }else if (buddyStatus.presence.indexOf("away")!=-1){
                            img.src="images/away.ico";				
                        }else if (buddyStatus.presence=="unavailable"){
                            img.src="images/unavailable.ico";
                        }else if (buddyStatus.presence.indexOf("available")!=-1){
                            img.src="images/available.ico";
                        }
                        var statusDiv = x[y].getElementsByTagName("span");
                        for(var i=0;i<statusDiv.length;i++){
                            if(statusDiv[i].id=="STATUS"){
                                if (buddyStatus.status.length>0) buddyStatus.status="( "+buddyStatus.status+" )";
                                statusDiv[i].innerHTML=buddyStatus.status;
                            }
                        }
                    }
                }else if (!!data.groups) {
                    //alert("Groups"+data.data.groups);
                    eval("groups="+data.groups);
                    $("#newGroup").autocomplete(groups, {
                        multiple: true,
                        autoFill: true,
                        minChars: 0,
                        width: 310,
                        matchContains: true,
                        highlightItem: false
                    });
                    var mainDiv = document.getElementById('notaccordion');
                    for(var i=0;i< groups.length;i++){
	
                        if(groups[i]!=""){
                            //alert(""+groups[i]);
                            var divGroup = "<h3><a href='#'>"+groups[i]+"</a></h3><div style='display: none;' id='USER_GROUP_"+groups[i]+"' ></div>";
                            mainDiv.innerHTML=mainDiv.innerHTML+divGroup;			
                        }

                    }
                    $("#notaccordion").addClass("ui-accordion ui-widget ui-helper-reset ui-accordion-icons")
                    .find("h3")
                    .addClass("ui-accordion-header ui-helper-reset ui-state-default ui-corner-top ui-corner-bottom")
                    .prepend('<span class="ui-icon ui-icon-triangle-1-e"/ >')
                    .click(function() {
                        $(this).toggleClass("ui-accordion-header-active ui-state-active ui-state-default ui-corner-bottom")
                        .find("> .ui-icon").toggleClass("ui-icon-triangle-1-s")
                        .end().next().toggleClass("ui-accordion-content-active ui-accordion-content ui-helper-reset ui-widget-content ui-corner-bottom").toggle();
                        return false;
                    });

                }else if (!!data.buddies) {
			
                    eval("buddies="+data.buddies);
                    //alert("buddies"+data.buddies);
                    $("#usersInvite").autocomplete(buddies, {
                        multiple: true,
                        autoFill: true,
                        minChars: 0,
                        width: 310,
                        matchContains: true,
                        highlightItem: false,
                        formatItem: function(row) {
                            return row.email;
                        },
                        formatResult: function(row) {
                            return row.email;
                        }
                    });
                    eval("allUsers="+data.allUsers);
                    $("#newEmail").autocomplete(allUsers, {
                        minChars: 0,
                        width: 310,
                        matchContains: true,
                        highlightItem: false,
                        formatItem: function(row, i, max, term) {
                            return row.name.replace(new RegExp("(" + term + ")", "gi"), "<strong>$1</strong>") + "<br><span style='font-size: 80%;'>Email: &lt;" + row.email + "&gt;</span>";
                        },
                        formatResult: function(row) {
                            return row.email;
                        }
                    });

			
			
			
                    for(var i=0;i< buddies.length;i++){
                        //alert("User:"+buddies[i].email+" belongs to :"+buddies[i].group.length);
                        if(buddies[i].group.length==0){
                            var mainDiv = document.getElementById('USER_GROUP_');
                            //alert(buddies[i].presence);
                            var presence="unavailable";
                            if(buddies[i].presence.indexOf("dnd")!=-1){
                                presence="busy";
                            }else if (buddies[i].presence.indexOf("away")!=-1){
                                presence="away";
                            }else if (buddies[i].presence=="unavailable"){
                                presence="unavailable";
                            }else if (buddies[i].presence.indexOf("available")!=-1){
                                presence="available";
                            }
                            if (buddies[i].status.length>0) buddies[i].status="( "+buddies[i].status+" )";
                            var newdiv = document.createElement('div');
                            newdiv.setAttribute('id','USER_STATUS_'+buddies[i].email);
                            newdiv.setAttribute('name','USER_STATUS_'+buddies[i].email);
                            newdiv.setAttribute('style','cursor:pointer;cursor:hand');
                            newdiv.innerHTML = "<img src='images/"+presence+".ico' id='USER_IMG' width='17px' height='17px' >"
                                +" <span id='USER_NAME' style='vertical-align:top' onclick='openChatTab(\""+buddies[i].email+"\",true,\""+buddies[i].name+"\")'>"+buddies[i].name
                                +"</span> <span id='STATUS' style='vertical-align:top'>"+buddies[i].status+"</span>"
                                +"<img src='images/delete-icon.png' alt='Delete' onclick='removeUser(\""+buddies[i].email+"\",\"\")'>"
                                +"<input type='hidden' id='TABINDEX' value='"+counter+"'>";
                            mainDiv.appendChild(newdiv);
                        }else{
                            for(var j=0;j< buddies[i].group.length;j++){
                                var mainDiv = document.getElementById('USER_GROUP_'+buddies[i].group[j]);
                                //alert(buddies[i].presence);
                                var presence="unavailable";
                                if(buddies[i].presence.indexOf("dnd")!=-1){
                                    presence="busy";
                                }else if (buddies[i].presence.indexOf("away")!=-1){
                                    presence="away";
                                }else if (buddies[i].presence=="unavailable"){
                                    presence="unavailable";
                                }else if (buddies[i].presence.indexOf("available")!=-1){
                                    presence="available";
                                }
                                if (buddies[i].status.length>0) buddies[i].status="( "+buddies[i].status+" )";
                                var newdiv = document.createElement('div');
                                newdiv.setAttribute('id','USER_STATUS_'+buddies[i].email);
                                newdiv.setAttribute('name','USER_STATUS_'+buddies[i].email);
                                newdiv.setAttribute('style','cursor:pointer;cursor:hand');
                                newdiv.innerHTML = "<img src='images/"+presence+".ico' id='USER_IMG' width='17px' height='17px' >"
                                    +" <span id='USER_NAME' style='vertical-align:top' onclick='openChatTab(\""+buddies[i].email+"\",true,\""+buddies[i].name+"\")'>"+buddies[i].name
                                    +"</span> <span id='STATUS' style='vertical-align:top'>"+buddies[i].status+"</span>"
                                    +"<img src='images/delete-icon.png' alt='Delete' onclick='removeUser(\""+buddies[i].email+"\",\""+buddies[i].group[j]+"\")'>"
                                    +"<input type='hidden' id='TABINDEX' value='"+counter+"'>";
                                mainDiv.appendChild(newdiv);
                            }
                        }
                        counter++;
                    }
                }

                //chatMessagesBox.scrollTop = chatMessagesBox.scrollHeight;
            }
	
            function chat(username) {
                //var username = document.getElementById('touser').value;
                if(document.getElementById('GROUPCHATINDEX_'+username)){
                    groupChat(username);
                }else{
                    var message = document.getElementById(username+'_ChatText').value;
                    var json = {chat:  escapeQuotes(message)  ,
                        touser: escapeQuotes(username)};
                    cometd.publish("/"+chatRoomName, json);
                    document.getElementById(username+'_ChatText').value="";
                    updateChat(chatRoomName,username,message);
                }
            }
            function sendFileMessage(username,file) {
                //var username = document.getElementById('touser').value;
                var message = "Sent a file: <a href='tmp/"+file+"' target='_blank' >"+file+"</a>";
                if(document.getElementById('GROUPCHATINDEX_'+username)){
                    var server = document.getElementById('GROUPCHATSERVER_'+username).value;
                    var statusJson = {confMessage:escapeQuotes(message) ,confName:username,confServer:server};
                    cometd.publish("/"+chatRoomName, statusJson);
                    //document.getElementById(room+'_ChatText').value="";
                }else{
                    //var message = document.getElementById(username+'_ChatText').value;
                    var json = {chat:  escapeQuotes(message)  ,
                        touser: escapeQuotes(username)};
                    cometd.publish("/"+chatRoomName, json);
                    //document.getElementById(username+'_ChatText').value="";
                    updateChat(chatRoomName,username,message);
                }
            }
            function groupChat(room){
                var message = document.getElementById(room+'_ChatText').value;
                //var room = document.getElementById('roomName').value;
                var server = document.getElementById('GROUPCHATSERVER_'+room).value;
                var statusJson = {confMessage:escapeQuotes(message) ,confName:room,confServer:server};
                cometd.publish("/"+chatRoomName, statusJson);
                document.getElementById(room+'_ChatText').value="";

            }
            function updateChat(fromUser,inUser,chat){
                //alert(user+":"+chat);
                var index = getMyTab(inUser);
		
                if(document.getElementById('tab-'+index)){
                    var chatArea = document.getElementById('tab-'+index).getElementsByTagName("DIV");
                    //alert(chatArea[0]);
                    //alert("called");
                    var currentTime = new Date();
                    var month = currentTime.getMonth() + 1;
                    var day = currentTime.getDate();
                    var year = currentTime.getFullYear();
                    var hours = currentTime.getHours();
                    var minutes = currentTime.getMinutes();
                    var seconds = currentTime.getSeconds();
                    chatArea[0].innerHTML+="<br/><b>"+"("+month+"/"+day+"/"+year+" "+hours+":"+minutes+":"+seconds+") "+fromUser + ":</b> " + chat;
                    chatArea[0].scrollTop = chatArea[0].scrollHeight;
                }
		
                var selected = $( "#tabs" ).tabs('option', 'selected');
		
                var thisIndex = getIndexForId("tab-"+index);
                //alert(selected+";"+thisIndex);
                if(selected!=thisIndex)
                    document.getElementById('tag-#tab-'+index).className="chatAlert";
		
            }
            function updateConfChat(fromUser,roomName,chat){
                //alert(fromUser+":"+chat+":"+roomName);
                var index = document.getElementById('GROUPCHATINDEX_'+roomName).value;
                //alert(index);
                if(document.getElementById('tab-'+index)){
                    var chatArea = document.getElementById('tab-'+index).getElementsByTagName("DIV");
                    //alert(chatArea[0]);
                    //alert("called");
                    var currentTime = new Date();
                    var month = currentTime.getMonth() + 1;
                    var day = currentTime.getDate();
                    var year = currentTime.getFullYear();
                    var hours = currentTime.getHours();
                    var minutes = currentTime.getMinutes();
                    var seconds = currentTime.getSeconds();
                    chatArea[0].innerHTML+="<br/><b>"+"("+month+"/"+day+"/"+year+" "+hours+":"+minutes+":"+seconds+") "+fromUser + ":</b> " + chat;
                    chatArea[0].scrollTop = chatArea[0].scrollHeight;
                }
		
                var selected = $( "#tabs" ).tabs('option', 'selected');
		
                var thisIndex = getIndexForId("tab-"+index);
                //alert(selected+";"+thisIndex);
                if(selected!=thisIndex)
                    document.getElementById('tag-#tab-'+index).className="chatAlert";
		
            }
            function getIndexForId(searchId){     
                var $MainTabs = $("#tabs").tabs();                                                                                       
                var existingIndex = $MainTabs.tabs('option','selected');                                                                  
                var myIndex = $MainTabs.tabs("select",
                searchId).tabs('option','selected');                                            
                $MainTabs.tabs("select", existingIndex);                                                                                
                return myIndex;
            } 
            function changeUserName() {
                var userName = document.getElementById('userName').value;
                if (userName != null && userName.length > 0) {
                    var userNameJson = {user: escapeQuotes(userName) };
                    cometd.publish("/"+chatRoomName, userNameJson);
                    hub.unsubscribe(chatRoomName);
                    chatRoomName = userName;
                    hub.subscribe(chatRoomName, chatUpdated);
                }
            }
            function changeStatus() {
                var status1 = document.getElementById('status').value;
		
                //if (status == null) {
		
                var mode1 = document.getElementById('mode').value;
                var statusJson = {status: escapeQuotes(status1),
                    mode:mode1};
                cometd.publish("/"+chatRoomName, statusJson);
		
                var statusImg = document.getElementById('myStatusImg');
                if(mode1=="dnd"){
                    statusImg.src="images/busy.ico";
                }else if (mode1=="away"){
                    statusImg.src="images/away.ico";				
                }else if (mode1=="available"){
                    statusImg.src="images/available.ico";
                }

            }
            function removeUser(email,group){
                //alert('remove'+email);
                var r=confirm("Confirm Removing User "+email+" from your contacts");
                if (r==true){
                    var statusJson = {removeUser: escapeQuotes(email)};
                    cometd.publish("/"+chatRoomName, statusJson);

                    var x = document.getElementsByName('USER_STATUS_'+email);
                    for(var y=0;x.length!=0;){
                        x[y].parentNode.removeChild(x[y]);
                    }
                }
            }
            function addUser(){
                var newEmail = document.getElementById('newEmail').value;
                //var newName = document.getElementById('newName').value;
                var newGroup = document.getElementById('newGroup').value;
                var groups = newGroup.split(",");
                if(newEmail.indexOf("@")==-1)
                    newEmail = newEmail+"@"+domainName;
                //var newGroup = '';
                //if (status == null) {
                var x = document.getElementsByName('USER_STATUS_'+newEmail);
                for(var y=0;x.length!=0;){
                    x[y].parentNode.removeChild(x[y]);
                }
                var mode = document.getElementById('mode').value;
                var statusJson = {addUser:escapeQuotes(newEmail) ,
                    name:newEmail,groups:newGroup};
                cometd.publish("/"+chatRoomName, statusJson);
                var presence="unavailable";
                if(groups.length==0){
                    var mainDiv = document.getElementById('USER_GROUP_');		
                    var newdiv = document.createElement('div');
                    newdiv.setAttribute('id','USER_STATUS_'+newEmail);
                    newdiv.setAttribute('name','USER_STATUS_'+newEmail);
                    newdiv.setAttribute('style','cursor:pointer;cursor:hand');
                    newdiv.innerHTML = "<img src='images/"+presence+".ico' id='USER_IMG' width='17px' height='17px' >"
                        +" <span id='USER_NAME' style='vertical-align:top' onclick='openChatTab(\""+newEmail+"\",true,\""+newEmail+"\")'>"+newEmail
                        +"</span> <span id='STATUS' style='vertical-align:top'></span><img src='images/delete-icon.png' alt='Delete' onclick='removeUser(\""+newEmail+"\",\"\")'>"
                        +"<input type='hidden' id='TABINDEX' value='"+counter+"'>";
                    mainDiv.appendChild(newdiv);
                }else{
                    for(var i=0;i<groups.length;i++){
                        groups[i]=$.trim(groups[i]);
                        if(!document.getElementById('USER_GROUP_'+groups[i])){
                            var mainDiv = document.getElementById('notaccordion');
                            var divGroup = "<h3><a href='#'>"+groups[i]+"</a></h3><div style='display: none;' id='USER_GROUP_"+groups[i]+"' ></div>";
                            mainDiv.innerHTML=mainDiv.innerHTML+divGroup;			

                            $("#notaccordion").addClass("ui-accordion ui-widget ui-helper-reset ui-accordion-icons")
                            .find("h3")
                            .addClass("ui-accordion-header ui-helper-reset ui-state-default ui-corner-top ui-corner-bottom")
                            .prepend('<span class="ui-icon ui-icon-triangle-1-e"/ >')
                            .click(function() {
                                $(this).toggleClass("ui-accordion-header-active ui-state-active ui-state-default ui-corner-bottom")
                                .find("> .ui-icon").toggleClass("ui-icon-triangle-1-s")
                                .end().next().toggleClass("ui-accordion-content-active ui-accordion-content ui-helper-reset ui-widget-content ui-corner-bottom").toggle();
                                return false;
                            });
                        }
                        var mainDiv = document.getElementById('USER_GROUP_'+groups[i]);		
                        var newdiv = document.createElement('div');
                        newdiv.setAttribute('id','USER_STATUS_'+newEmail);
                        newdiv.setAttribute('name','USER_STATUS_'+newEmail);
                        newdiv.setAttribute('style','cursor:pointer;cursor:hand');
                        newdiv.innerHTML = "<img src='images/"+presence+".ico' id='USER_IMG' width='17px' height='17px' >"
                            +" <span id='USER_NAME' style='vertical-align:top' onclick='openChatTab(\""+newEmail+"\",true,\""+newEmail+"\")'>"+newEmail
                            +"</span> <span id='STATUS' style='vertical-align:top'></span><img src='images/delete-icon.png' alt='Delete' onclick='removeUser(\""+newEmail+"\",\""+groups[i]+"\")'>"
                            +"<input type='hidden' id='TABINDEX' value='"+counter+"'>";
                        mainDiv.appendChild(newdiv);
                    }
                }
                counter++;
            }
            function addAutomaticUser(newEmail){
		
                //if (status == null) {
	
                var presence="unavailable";
                var mainDiv = document.getElementById('USER_GROUP_');		
                var newdiv = document.createElement('div');
                newdiv.setAttribute('id','USER_STATUS_'+newEmail);
                newdiv.setAttribute('name','USER_STATUS_'+newEmail);
                newdiv.setAttribute('style','cursor:pointer;cursor:hand');
                newdiv.innerHTML = "<img src='images/"+presence+".ico' id='USER_IMG' width='17px' height='17px' >"
                    +" <span id='USER_NAME' style='vertical-align:top' onclick='openChatTab(\""+newEmail+"\",true,\""+newEmail+"\")'>"+newEmail
                    +"</span> <span id='STATUS' style='vertical-align:top'></span><img src='images/delete-icon.png' alt='Delete' onclick='removeUser(\""+newEmail+"\",\"\")'>"
                    +"<input type='hidden' id='TABINDEX' value='"+counter+"'>";
                mainDiv.appendChild(newdiv);
                counter++;
            }
            function addChatRoom(roomName,server){
                var mainDiv = document.getElementById('GROUPS_LIST');	
                mainDiv.innerHTML = mainDiv.innerHTML+"<input type='hidden' id='GROUPCHATINDEX_"+roomName+"' value='"+counter+"'>";
                mainDiv.innerHTML = mainDiv.innerHTML+"<input type='hidden' id='GROUPCHATSERVER_"+roomName+"' value='"+server+"'>";
                counter++;
		
            }
            function removeChatRoom(roomName){
                var input = document.getElementById('GROUPCHATINDEX_'+roomName);	
                input.parentNode.removeChild(input);
            }
            function escapeQuotes(sString) {
                return sString.replace(/(\')/gi, "\\$1").replace(/(\\\\\')/gi, "\\'");
            }
	
            function checkForEnter(e,userName){
                var e = e || event;
                var key = e.keyCode || e.charCode;
                if(key == 13){
                    chat(userName);
                }
                return true;
            }
            function getMyTab(userName){
                var statusDiv = document.getElementById('USER_STATUS_'+userName).getElementsByTagName("input");
                var index=0;
                for(var i=0;i<statusDiv.length;i++){
                    if(statusDiv[i].id=="TABINDEX"){
                        index=statusDiv[i].value;
                        break;
                    }
                }
                return index;
            }

            function openGroupChatTab(roomName,open){
		
                var index = document.getElementById('GROUPCHATINDEX_'+roomName).value;

                if(document.getElementById('tab-'+index)){
                    if(open){
                        focusTab(index);
                    }
                }else{
                    newChatTab(roomName,index,open,roomName)
                    var parent =document.getElementById('tab-'+index);
                    parent.innerHTML= parent.innerHTML+"<input type='text' id='"+roomName+"_joinUsers' >"
                        +"<input type='button' value='Invite' onclick='invite(\""+roomName+"\")'>"
                }
            }


            function openChatTab(userName,open,displayName){

                var index = getMyTab(userName);

                if(document.getElementById('tab-'+index)){
                    if(open){
                        focusTab(index);
                    }
                }else{
                    newChatTab(userName,index,open,displayName)
                }
            }
            function focusTab(index){
                $( "#tabs" ).tabs('select', index);
                focusText(index);
            }
            function focusText(index){
                var statusDiv = document.getElementById('tab-'+index).getElementsByTagName("input");
                for(var i=0;i<statusDiv.length;i++){
                    if(statusDiv[i].type=='text'){
                        statusDiv[i].focus();
                        break;
                    }
                }
            }
            function newChatTab(userName,index,open,displayName){
	
                $( "#tabs" ).tabs( "add" ,'#tab-'+index,displayName);
			
                var x = document.getElementsByName('USER_STATUS_'+userName)
			
                for(var y=0;y<x.length;y++){
                    var statusDiv = x[y].getElementsByTagName("input");
                    for(var i=0;i<statusDiv.length;i++){
                        if(statusDiv[i].id=="TABINDEX"){
                            statusDiv[i].value=index;
                            break;
                        }
                    }
                }
                if(document.getElementById('tab-'+index)){
                    (document.getElementById('tab-'+index)).innerHTML="<DIV id='"+userName+"_ChatMessages' style='width:100%;height:200px;overflow:auto;-webkit-box-shadow: 10px 10px 5px #888888;box-shadow: 2px 2px 1px #888888;border:1px solid black;'></DIV>"
                        +"<br><input type='text' id='"+userName+"_ChatText' size='50' onkeypress='checkForEnter(event,\""+userName+"\")'>"
                        +"<input type='button' value='Send' onclick='chat(\""+userName+"\")'><br/><br/> ";
                    if(domainName!='gmail.com' && domainName!='chat.facebook.com')
                        (document.getElementById('tab-'+index)).innerHTML +="Send File:<br/><iframe src='uploadIndex.jsp?userName="+userName+"' frameborder='0' scrolling='no' width='400' height='50'></iframe>";
                }
                if(open){
                    focusTab(index);
                }
            }
            function startConf(){
                var room = document.getElementById('roomName').value;
                var users = $.trim(document.getElementById('usersInvite').value);
                var server = document.getElementById('server').value;
                //alert(users);
                var invi = users.split(",");
                var emails ="";
                for(var i=0;i<invi.length;i++){
                    if($.trim(invi[i])!=""){
                        if(invi[i].indexOf("@")==-1)
                            emails = emails+$.trim(invi[i])+"@"+domainName;
                        else
                            emails = emails+$.trim(invi[i]);
                        if((i+1)<invi.length)
                            emails = emails+"|";
                    }
                }	
                var statusJson = {startConf:escapeQuotes(room) ,confUsers:emails,confServer:server};
                cometd.publish("/"+chatRoomName, statusJson);
                addChatRoom(room,server);
                openGroupChatTab(room,true);
            }
	
            function invite(room){
                var txt = $.trim(document.getElementById(room+'_joinUsers').value);
                var invi = txt.split(",");
                var emails ="";
                for(var i=0;i<invi.length;i++){
                    if($.trim(invi[i])!=""){
                        if(invi[i].indexOf("@")==-1)
                            emails = emails+$.trim(invi[i])+"@"+domainName;
                        else
                            emails = emails+$.trim(invi[i]);
                        if((i+1)<invi.length)
                            emails = emails+"|";
                    }
                }	
                var statusJson = {inviteConf: escapeQuotes(room),confUsers:emails};
                cometd.publish("/"+chatRoomName, statusJson);
                document.getElementById(room+'_joinUsers').value="";
            }
            function sendFile(file,user){
	
                //alert(file+"-"+user);
                // var user = document.getElementById('FILEFRAME_'+selected).name;
                //alert(file);
                //alert(user);
                sendFileMessage(user,file) 
            }
            cometd.subscribe("/"+chatRoomName, chatUpdated);
        </script>

        <style>
            #tabs { margin-top: 1em; }
            #tabs li .ui-icon-close { float: left; margin: 0.4em 0.2em 0 0; cursor: pointer; }
            #add_tab { cursor: pointer; }
            .chatAlert {
                background: url("backgrnd.gif") #DFEFFC;
                background-size: 100%;
                /* for IE */
                filter:alpha(opacity=50);
                /* CSS3 standard */
                opacity:0.5;   
            }
            label {
                width: 9em;
                float: left;
                text-align: right;
                margin-right: 0.5em;
                display: block;
            }

            fieldset
            {
                border: 1px solid #2e6e9e;
                width: 25em;
            }

            legend
            {
                color: #FFFFFF;
                background: #2e6e9e;
                border: 1px solid #2e6e9e;
                padding: 2px 6px;
            } 
            body {font-size:75%;}
            input {
                color: #000000;
                background: #FFFFFF;
                text-shadow: none;
            }

            select option {
                padding-left:20px;
            }
            select   {
                height: 18px;
                font: 200 11px Arial, Helvetica, sans-serif;  
                margin: 0px; 
                padding-right: 0px 0px 0px 0px;
                border: 1px #FFFFFF solid;  
            }
        </style>
    </head>
    <body onload="getBuddies()" onunload="">
          <div style ="font-size:150%;">
            <img id="myStatusImg" width='17px' height='17px' src='images/available.ico'/> <%=userName%>
            <select style="align:bottom;background:url('images/dropdown.ico');background-size:12px 12px;background-repeat:no-repeat;padding-left:20px;position:relative;z-index:9;width:7px;height:15px" id="mode" onchange="changeStatus()" >
                <option style="background:url('images/available.ico');background-repeat:no-repeat;background-size:15px 15px;" value="available">Available</option>
                <option style="background:url('images/busy.ico');background-repeat:no-repeat;background-size:15px 15px;" value="dnd">Busy</option>
                <option style="background:url('images/away.ico');background-repeat:no-repeat;background-size:15px 15px;" value="away">Away</away>
            </select>
            <input type="button" value="Sign out" onclick="logoff()"><br/>
            <span style ="font-size:80%;">Status: <input style="border: 1px solid #006;font-size:80%;" type="text" id="status">
                <input type="button" value="Change" onclick="changeStatus()">
            </span>
        </div>
        <br/>
        <div style="width:1000px">
            <% if (!domain.equalsIgnoreCase("chat.facebook.com")) {
            %>
            <fieldset>
                <legend>Add User</legend>
                <label>UserName:</label><input type="text" id="newEmail"><br/>
                <!--NewUserName:<input type="text" id="newName"><br/>-->
                <label>Group:</label><input type="text" id="newGroup"><br/>
                Enter group names separated by comma (,) <br/>
                <input type="button" value="Add" onclick="addUser()">
            </fieldset>
            <% if (!domain.equalsIgnoreCase("gmail.com")) {
            %>
            <fieldset>
                <legend>Chat Room</legend>
                <label>Room:</label><input type="text" id="roomName">
                <label>Server:</label><input type="text" id="server" value=""><br/>
                <label>Users to Invite:</label><input type="text" id="usersInvite">
                <input type="button" value="Start" onclick="startConf()"><br/>
            </fieldset>
            <% }
    }%>
        </div>
        <div >
            <div id="tabs">
                <ul>
                    <li><a href="#main">Contacts</a></li>
                </ul>
                <div id="main">
                    <div id="notaccordion">
                        <h3 ><a href="#">DEFAULT</a></h3>
                        <div id="USER_GROUP_" style="display: none;">
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <!--<textarea id="chatMessages" rows="1" cols="1" style="position: absolute;visiblity: hidden"></textarea>-->
    </div>
    <div id='GROUPS_LIST'>
    </div>
    <div id='body' style ="font-size:80%">
    </div>
    <div style ="font-size:90%;position:relative;top:105%;left:40%;">
        © Copyright 20011 Marist College,
        XMPPWebChat 1.0-beta1.
    </div>
</body>
<script>

    function titleAlert(i){
        var flag = 0;
        $('#tabs ul li a').each(function(){
            var url = $(this).attr('className');
            var tit="";		
            if(url=="chatAlert"){
                flag=1;
		
            }
        });
        if(flag==1){
            if(i == 0){
                tit = "Chat";
                i = 1;
            }
            else if(i == 1){
                tit = "**Chat**";
                i = 0;
            }
            document.title = tit;
        }else{
            document.title = "Chat";
        }
        timer = window.setTimeout("titleAlert("+i+")",500);
    }
    titleAlert(1);

</script>

</html>

