/**
 * Copyright (C) 2011  Adam Hocek. Contact: ahocek@gmail.com, Ghattamaneni Uday. 
 * Contact: ghattamaneni.uday@gmail.com 
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
 */
package edu.maristit.xmppwebchat;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import org.cometd.bayeux.client.ClientSessionChannel;
import org.cometd.bayeux.server.BayeuxServer;
import org.cometd.bayeux.server.ServerChannel;
import org.cometd.bayeux.server.ServerSession;

import org.cometd.server.AbstractService;
import org.jivesoftware.smack.Chat;
import org.jivesoftware.smack.ChatManagerListener;
import org.jivesoftware.smack.Connection;
import org.jivesoftware.smack.MessageListener;
import org.jivesoftware.smack.PacketListener;
import org.jivesoftware.smack.Roster;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.RosterGroup;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.filter.ToContainsFilter;
import org.jivesoftware.smack.packet.IQ;
import org.jivesoftware.smack.packet.Message;
import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smack.packet.RosterPacket;
import org.jivesoftware.smack.packet.Presence.Mode;
import org.jivesoftware.smack.packet.Presence.Type;
import org.jivesoftware.smackx.Form;
import org.jivesoftware.smackx.ReportedData;
import org.jivesoftware.smackx.ReportedData.Column;
import org.jivesoftware.smackx.ReportedData.Row;
import org.jivesoftware.smackx.muc.InvitationListener;
import org.jivesoftware.smackx.muc.MultiUserChat;
import org.jivesoftware.smackx.packet.DelayInformation;
import org.jivesoftware.smackx.search.UserSearchManager;
import org.json.JSONArray;

class ChatListener extends AbstractService implements ClientSessionChannel.MessageListener,
        ChatManagerListener, MessageListener {

    private String chatRoom = "ChatRoom";
    private XMPPConnection connection;
    private Roster roster;
    private Chat chat = null;
    private List<Buddy> buddies = new ArrayList<Buddy>();
    private List<MultiUserChat> myChatRooms = new ArrayList<MultiUserChat>();
    private List<Map<String, String>> offlines = new ArrayList<Map<String, String>>();
    private String conferenceServer = "";
    private ServerSession serverSession;

    public void processMessage(Chat chat, Message message) {
        String from = message.getFrom();
        String body = message.getBody();
        String[] username = from.split("/");

        //client.isConnected()
        System.out.println(String.format("Received message '%1$s' from %2$s",
                body, from));

        try {
            if (this.chat == null) {
                this.chat = chat;
            }
            if (body != null) {
                sendToPage(body, username[0], chat.getParticipant());
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void destroy() {
        try {
            System.out.println("Destroying:" + this);
            System.out.println("logging out Client:" + chatRoom
                    + ",User:" + connection.getUser());
            for (MultiUserChat chatRoom : myChatRooms) {
                try {
                    chatRoom.destroy("Logged out.", "");
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
            connection.getChatManager().removeChatListener(this);

            serverSession.disconnect();

            connection.disconnect();

            try {
                this.finalize();
            } catch (Throwable e) {
                e.printStackTrace();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public ChatListener(BayeuxServer bayeuxServer, String name) {
        super(bayeuxServer, name);
        ServerChannel sc = bayeuxServer.getChannel("/" + name);
        if (sc != null) {
            sc.remove();
        }
        addService("/" + name, "processCometMessage");
        this.chatRoom = name;

    }

    public void init(XMPPConnection connection) {

        try {

            this.connection = connection;

            if (connection.isAuthenticated()) {
                String[] username = connection.getUser().split("/");

                if (username.length > 0) {
                    chatRoom = username[0].toString();
                }
                System.out.println("ChatRoom:" + chatRoom
                        + " created for user:" + connection.getUser());
                printRoster();

                MultiUserChat.addInvitationListener(connection,
                        new InvitationListener() {

                            @Override
                            public void invitationReceived(Connection conn,
                                    String room, String inviter, String reason,
                                    String password, Message arg5) {
                                // Reject the invitation
                                // MultiUserChat.decline(conn, room, inviter,
                                // "I'm busy right now");
                                // MultiUserChat.addInvitationListener(connection,
                                // listener)
                                joinConference(room);
                            }
                        });

            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void processCometMessage(ServerSession remote, Map<String, String> fields) {
        this.serverSession = remote;
        //System.out.println("Got:'"+fields+"' in:"+chatRoom);

        if (chatRoom.equals(chatRoom)) {


            if (fields.containsKey("")) {
            } else if (fields.containsKey("chat")) {
                // System.out.println("Sending CHat");
                sendChatMessage(fields);
            } else if (fields.containsKey("status")) {
                Mode mode = Mode.available;
                if (fields.get("mode").equalsIgnoreCase("dnd")) {
                    mode = Mode.dnd;
                } else if (fields.get("mode").equalsIgnoreCase("away")) {
                    mode = Mode.away;
                } else if (fields.get("mode").equalsIgnoreCase("xa")) {
                    mode = Mode.xa;
                } else if (fields.get("mode").equalsIgnoreCase("available")) {
                    mode = Mode.available;
                }
                changeStatus(fields.get("status"), mode);
            } else if (fields.containsKey("request")) {

                List<String> groupsString = new ArrayList<String>();
                for (RosterGroup grp : roster.getGroups()) {
                    groupsString.add(grp.getName());
                }
                sendGroups((new JSONArray(groupsString)).toString());
                try {
                    Thread.sleep(500);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
                sendBuddy(buddies);
                System.out.println("BUDDIES Requested:" + buddies);
                sendOfflineChat();

            } else if (fields.containsKey("logout")) {

                this.destroy();
                // System.out.println("Destroying :" + this.toString());
            } else if (fields.containsKey("addUser")) {
                System.out.println("Adding User:" + fields.get("addUser"));
                String user = fields.get("addUser").toString();
                String[] groups = fields.get("groups").split(",");
                addUser(user, fields.get("name"), groups);
                try {
                    String presence = "";
                    if (roster.getPresence(user).isAvailable()) {
                        if (roster.getPresence(user).getMode() == null) {
                            presence = "available";
                        } else {
                            presence = roster.getPresence(user).getMode().toString();
                        }
                    } else {
                        presence = "unavailable";
                    }

                    sendPresenceToPage(user, new Buddy(user, user,
                            presence));
                } catch (Exception e) {
                    e.printStackTrace();
                }
            } else if (fields.containsKey("removeUser")) {
//				//System.out.println("Removing User:" + fields.get("removeUser"));
                String email = fields.get("removeUser").toString();
                removeUser(email);
            } else if (fields.containsKey("startConf")) {
                conferenceServer = fields.get("confServer");
//				System.out.println("Creating Conference:"
//						+ fields.get("startConf"));
                String users[] = fields.get("confUsers").split("\\|");
                startConference(fields.get("startConf"), fields.get("confServer"), Arrays.asList(users), "");
            } else if (fields.containsKey("joinConf")) {
                conferenceServer = fields.get("confServer");
                //System.out.println("Joining Conference:"
                //+ fields.get("joinConf"));
                joinConference(fields.get("joinConf"));
            } else if (fields.containsKey("confMessage")) {
//				System.out.println("Sending Message '"
//						+ fields.get("confMessage") + "' to Conference:"
//						+ fields.get("confName"));
                sendMessageToConference(fields.get("confName") + "@"
                        + fields.get("confServer"), fields.get("confMessage"));
            } else if (fields.containsKey("inviteConf")) {
//				System.out.println("Inviting '"
//						+ fields.get("confUsers") + "' to Conference:");
                String users[] = fields.get("confUsers").split("\\|");
                inviteConference(fields.get("inviteConf"), Arrays.asList(users));
            }
        }
    }

    private void changeStatus(String status, Mode mode) {

        // Presence.Type type = Type.available;
        Presence presence = new Presence(Type.available);
        presence.setMode(mode);
        presence.setStatus(status);
        if (connection.isConnected()) {
            connection.sendPacket(presence);
        } else {
            try {
                connection.connect();
                connection.sendPacket(presence);
            } catch (XMPPException e) {
                e.printStackTrace();
            }
        }
        System.out.println(connection.getUser() + " Status Changed to "
                + status);

    }

    private void sendNotification(Map<String, String> notificationMessage) {
        // Payload notification = new JsonPayload(topic);
        // notification.addField("notification", notificationMessage);
        //streamingServer.publish(topic, notificationMessage);
        serverSession.deliver(getServerSession(), "/" + chatRoom, notificationMessage, null);
    }

    private void sendOfflineChat() {
        for (Map<String, String> offline : offlines) {
            Map<String, String> chatMessage = new HashMap<String, String>();

            chatMessage.put("user", offline.get("from"));
            chatMessage.put("chat", "" + offline.get("message"));
            try {
                if (chat == null) {
                    System.out.println("Chat not started");
                    this.chat = connection.getChatManager().createChat(
                            offline.get("from"), this);
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
            System.out.println("Sending offline:" + chatMessage + ",to:"
                    + chatRoom);
            sendNotification(chatMessage);
        }
    }

    private void sendChatMessage(Map<String, String> fields) {
        if (fields.containsKey("chat")) {
            Map<String, String> chatMessage = new HashMap<String, String>();

            chatMessage.put("user", chatRoom);
            chatMessage.put("chat", "" + fields.get("chat"));
            try {
                if (chat == null) {
                    System.out.println("Chat not started");
                    this.chat = connection.getChatManager().createChat(
                            fields.get("touser"), this);

                } else {
                    if (!fields.get("touser").isEmpty()
                            && !chat.getParticipant().equalsIgnoreCase(
                            fields.get("touser"))) {
                        this.chat = connection.getChatManager().createChat(
                                fields.get("touser"), this);
                    }
                    // System.out.println("Participant"+chat.getParticipant());
                }
                chat.sendMessage(fields.get("chat"));
            } catch (Exception e) {
                e.printStackTrace();
            }
            sendNotification(chatMessage);
        } else {
            // System.err.println("Incoming payload did not contain chat message, full message: "
            // + fields.toString());
        }
    }

    private void sendToPage(String message, String userName, String displayName) {
        Map<String, String> chatMessage = new HashMap<String, String>();
        String username = "" + userName;
        chatMessage.put("user", username);
        chatMessage.put("displayName", displayName);
        chatMessage.put("chat", "" + message);
        sendNotification(chatMessage);
    }

    private void sendToConfPage(String roomName, String message, String userName, String server) {
        Map<String, String> chatMessage = new HashMap<String, String>();

        chatMessage.put("fromUser", userName);
        chatMessage.put("roomName", roomName);
        chatMessage.put("confChat", message);
        chatMessage.put("server", server);
        sendNotification(chatMessage);
    }

    private void sendBuddy(List<Buddy> buddies) {
        List<Buddy> users = new ArrayList<Buddy>();
        try {
            String[] domain = chatRoom.split("@");
            UserSearchManager search = new UserSearchManager(connection);
            Form searchForm = search.getSearchForm("search." + domain[1]);
            Form answerForm = searchForm.createAnswerForm();

            answerForm.setAnswer("Username", true);
            answerForm.setAnswer("Name", true);
            answerForm.setAnswer("search", "*");
            ReportedData data = search.getSearchResults(answerForm, "search." + domain[1]);
            //System.out.println("Data:"+data);
            for (Iterator<Row> i = data.getRows(); i.hasNext();) {
                Row r = i.next();
                // System.out.print("Row:"+r.toString());
                Buddy b = new Buddy("", "", "");
                for (Iterator<Column> j = data.getColumns(); j.hasNext();) {
                    String col = ((Column) j.next()).getVariable();
                    System.out.print(col + ":");
                    for (Iterator it1 = r.getValues(col); it1.hasNext();) {
                        String val = it1.next().toString();
                        System.out.println(val);
                        if (col.equalsIgnoreCase("jid")) {
                            b.setEmail(val);
                        }
                        if (col.equalsIgnoreCase("Name")) {
                            b.setName(val);
                        }
                        //map.put(col,val);
                    }
                }
                users.add(b);
            }
            System.out.println("users Requested:" + users);
        } catch (Exception e) {
            e.printStackTrace();
        }
        // String username = "User " + userName;
        Map<String, String> chatMessage = new HashMap<String, String>();
       
        Collections.sort(buddies, new Comparator(){
 
            public int compare(Object o1, Object o2) {
                Buddy p1 = (Buddy) o1;
                Buddy p2 = (Buddy) o2;
               return p1.getPresence().compareToIgnoreCase(p2.getPresence());
            }
 
        });
        chatMessage.put("buddies", buddies.toString());
        chatMessage.put("allUsers", users.toString());
        sendNotification(chatMessage);
    }

    private void sendGroups(String groups) {
        // String username = "User " + userName;
        Map<String, String> chatMessage = new HashMap<String, String>();
        chatMessage.put("groups", groups.toString());
        sendNotification(chatMessage);
    }

    private void sendPresenceToPage(String userName, Buddy buddy) {
        Map<String, String> chatMessage = new HashMap<String, String>();
        String username = userName;
        chatMessage.put("user", username);
        chatMessage.put("buddyStatus", "" + buddy);
        sendNotification(chatMessage);
    }

    public void printRoster() throws Exception {
        this.roster = connection.getRoster();
        Collection<RosterEntry> entries = roster.getEntries();
        for (RosterEntry entry : entries) {
            System.out.println(String.format("Buddy:%1$s - Status:%2$s", entry.getUser(), entry.getStatus()));
            System.out.println("Status:" + roster.getPresence(entry.getUser()));
            List<String> groups = new ArrayList<String>();
            if (entry.getGroups() != null && entry.getGroups().size() > 0) {
                for (RosterGroup rg : entry.getGroups()) {
                    groups.add(rg.getName());
                }
            }
            if (roster.getPresence(entry.getUser()).isAvailable()) {
                if (roster.getPresence(entry.getUser()).getMode() == null) {
                    buddies.add(new Buddy(entry.getName(), entry.getUser(),
                            "available", groups));
                } else {
                    buddies.add(new Buddy(entry.getName(), entry.getUser(),
                            roster.getPresence(entry.getUser()).getMode().toString(), groups));
                }
            } else {
                buddies.add(new Buddy(entry.getName(), entry.getUser(),
                        "unavailable", groups));
            }

        }

        roster.setSubscriptionMode(Roster.SubscriptionMode.manual);
        roster.addRosterListener(new RosterListener() {

            public void entriesAdded(Collection<String> addresses) {
            }

            public void entriesDeleted(Collection<String> addresses) {
            }

            public void entriesUpdated(Collection<String> addresses) {
            }

            public void presenceChanged(Presence presence) {
                try {
                    if (connection.isConnected()) {
//                        System.out.println("Presence changed: "
//                                + presence.getFrom()
//                                + "->"
//                                + presence
//                                + " in:"
//                                + connection.getAccountManager().getAccountAttribute("username"));
                    }

                } catch (Exception e) {
                    e.printStackTrace();
                }
                String[] username = presence.getFrom().split("/");

                //System.out.println("Buddies in " + chatRoom + ":" + buddies);
                for (Buddy buddy : buddies) {
                    if (username[0].equalsIgnoreCase(buddy.getEmail())) {
                        if (presence.isAvailable()) {
                            if (presence.getMode() != null) {
                                buddy.setPresence(presence.getMode().name());
                            } else {
                                buddy.setPresence("available");
                            }
                        } else {
                            buddy.setPresence("unavailable");
                        }
                        if (presence.getStatus() == null) {
                            buddy.setStatus("");
                        } else {
                            buddy.setStatus(presence.getStatus());
                        }
                        sendPresenceToPage(username[0], buddy);
                        break;
                    }
                }
            }
        });

        PacketListener myListener = new PacketListener() {

            @Override
            public void processPacket(Packet packet) {
                // Do something with the incoming packet here.
                // System.out.println("Packet:"+packet.getClass());
                if (packet.getClass().toString().equalsIgnoreCase(
                        "class org.jivesoftware.smack.packet.Presence")) {

                    Presence pr = (Presence) packet;
                    // System.out.println("packet XML:"+packet.toXML());
                    if (pr.getType().equals(Presence.Type.subscribe)) {
                        try {
                            String[] from = pr.getFrom().split("/");
                            System.out.println("Packet Type in process:"
                                    + pr.getType() + ", from:" + from[0]);
                            Presence subscribed = new Presence(
                                    Presence.Type.subscribed);
                            subscribed.setTo(from[0]);
                            subscribed.setFrom(chatRoom);
                            connection.sendPacket(subscribed);

                            connection.getRoster().createEntry(from[0],
                                    from[0], null);
                            boolean found = false;
                            for (Buddy buddy : buddies) {
                                if (buddy.getEmail().equalsIgnoreCase(from[0])) {
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) {
                                buddies.add(new Buddy(from[0], from[0],
                                        "unavailable"));
                            }
                            sendPresenceToPage(from[0], new Buddy(
                                    from[0], from[0], roster.getPresence(
                                    from[0]).getMode().toString()));
                        } catch (XMPPException e) {
                            e.printStackTrace();
                        }
                    }
                }
                if (packet.getClass().toString().equalsIgnoreCase(
                        "class org.jivesoftware.smack.packet.Message")) {
                    Message m = (Message) packet;

                    if (m.getBody() != null) {
                        System.out.println("Body is " + m.getBody());
                        DelayInformation inf = null;
                        try {
                            inf = (DelayInformation) packet.getExtension("x",
                                    "jabber:x:delay");

                            // get offline message timestamp
                            System.out.println("Inf:" + inf + ",PacketType:");
                            if (inf != null) {

                                Map<String, String> messages = new HashMap<String, String>();
                                String[] username = m.getFrom().split("/");
                                messages.put("from", username[0]);
                                messages.put("message", m.getBody());
                                // Date date = inf.getStamp();
                                messages.put("time", inf.getStamp().toString());
                                System.out.println("Adding offline:" + messages);
                                offlines.add(messages);
                            }
                        } catch (Exception e) {
                            // log.error(e);
                            e.printStackTrace();
                        }
                    }
                    // m.getXmlns()
                    // System.out.println("XML:" + packet.toXML());
                }
            }
        };
        // Register the listener.
        connection.addPacketListener(myListener, new ToContainsFilter(chatRoom));

    }

    public void addUser(String userName, String email, String[] groups) {
        // this.roster = connection.getRoster();
        // List<String> groupsList = new ArrayList<String>();
        try {
            if (groups.length <= 0) {
                buddies.add(new Buddy(userName, email, "unavailable"));
            } else {

                buddies.add(new Buddy(userName, email, "unavailable", Arrays.asList(groups)));
            }
            roster.createEntry(email, userName, groups);

        } catch (XMPPException e) {
            e.printStackTrace();
        }

    }

    public void removeUser(String email) {
        try {
            RosterPacket pack = new RosterPacket();
            pack.setType(IQ.Type.SET);
            RosterPacket.Item item = new RosterPacket.Item(email, email);
            item.setItemType(RosterPacket.ItemType.remove);
            pack.addRosterItem(item);
            connection.sendPacket(pack);
            roster.removeEntry(roster.getEntry(email));
        } catch (XMPPException e) {
            e.printStackTrace();
        }
    }

    @Override
    public void chatCreated(Chat chat, boolean createdLocally) {
        // System.out.println(String.format("New Message Received message from '%1$s' ",
        // chat.getParticipant()));
        if (!createdLocally)
			;
        chat.addMessageListener(this);
    }

    public void startConference(String roomName, String server,
            List<String> users, String reason) {
        // Create a MultiUserChat using a Connection for a room
        MultiUserChat muc = new MultiUserChat(connection, roomName + "@"
                + server);

        PacketListener myListener = new PacketListener() {

            @Override
            public void processPacket(Packet packet) {
                //System.out.println("PacketData:" + packet.toXML());
                if (packet.getClass().toString().equalsIgnoreCase(
                        "class org.jivesoftware.smack.packet.Message")) {
                    Message m = (Message) packet;

                    if (m.getBody() != null) {
                        System.out.println("Body is " + m.getBody());
                        DelayInformation inf = null;
                        try {
                            inf = (DelayInformation) packet.getExtension(
                                    "x", "jabber:x:delay");


                            String[] username = m.getFrom().split("/");

                            String t[] = username[0].split("@");
                            System.out.println("Room:" + t[0] + ",msg:" + m.getBody() + ",User:" + username[1]);
                            sendToConfPage(t[0], m.getBody(), username[1], t[1]);

                        } catch (Exception e) {
                            e.printStackTrace();
                        }
                    }
                }
            }
        };
        muc.addMessageListener(myListener);

        PacketListener peopleListener = new PacketListener() {

            @Override
            public void processPacket(Packet packet) {
                //System.out.println("People PacketData:" + packet.toXML());
                if (packet.getClass().toString().equalsIgnoreCase(
                        "class org.jivesoftware.smack.packet.Presence")) {
                    Presence p = (Presence) packet;

                    try {
                        System.out.println("Presence from: " + p.getFrom());
                        System.out.println("Presence :" + p.toString());

                        String[] username = p.getFrom().split("/");
                        String t[] = username[0].split("@");
                        //System.out.println("Room:"+t[0]+",msg:"+m.getBody()+",User:"+username[1]);
                        if (p.toString().equalsIgnoreCase("available")) {
                            sendToConfPage(t[0], "** '" + username[1] + "' joined the room **", "", t[1]);
                        } else if (p.toString().equalsIgnoreCase("unavailable")) {
                            sendToConfPage(t[0], "** '" + username[1] + "' left the room **", "", t[1]);
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            }
        };
        muc.addParticipantListener(peopleListener);
        try {
            // Create the room
            muc.create(chatRoom);
            // Send an empty room configuration form which indicates that we
            // want
            // an instant room
            muc.sendConfigurationForm(new Form(Form.TYPE_SUBMIT));
            for (String user : users) {
                muc.invite(user, reason);
            }

            System.out.println("Created Chat Room :" + roomName + " with " + users);
            myChatRooms.add(muc);
        } catch (XMPPException e) {
            e.printStackTrace();
        }
    }

    public void sendMessageToConference(String room, String message) {
        try {
            getChatRoomByName(room).sendMessage(message);
        } catch (Exception e) {
            e.printStackTrace();
        }

    }

    public void inviteConference(String roomName, List<String> users) {
        MultiUserChat muc = null;
        if (roomName.contains("@")) {
            muc = getChatRoomByName(roomName);
        } else {
            muc = getChatRoomByName(roomName + "@" + conferenceServer);
        }
        System.out.println("invited #:" + users.size());
        if (muc != null) {
            for (String user : users) {
                muc.invite(user, "Invite");
                System.out.println("invited :" + user);
            }
        }
    }

    public void joinConference(String room) {
        MultiUserChat muc = new MultiUserChat(connection, room);
        try {
            muc.join(chatRoom);
            myChatRooms.add(muc);
            PacketListener myListener = new PacketListener() {

                @Override
                public void processPacket(Packet packet) {
                    //System.out.println("\nIN:" + chatRoom);
                    //System.out.println("PacketClass:" + packet.getClass());
                    //System.out.println("PacketProperties:"
                    //+ packet.getPropertyNames());
                    //System.out.println("PacketData:" + packet.toXML());
                    if (packet.getClass().toString().equalsIgnoreCase(
                            "class org.jivesoftware.smack.packet.Message")) {
                        Message m = (Message) packet;

                        if (m.getBody() != null) {
                            System.out.println("Body is " + m.getBody());
                            DelayInformation inf = null;
                            try {
                                inf = (DelayInformation) packet.getExtension(
                                        "x", "jabber:x:delay");

                                // get offline message timestamp

                                String[] username = m.getFrom().split("/");

                                String t[] = username[0].split("@");
                                System.out.println("Room:" + t[0] + ",msg:" + m.getBody() + ",User:" + username[1]);
                                sendToConfPage(t[0], m.getBody(), username[1], t[1]);

                            } catch (Exception e) {
                                // log.error(e);
                                e.printStackTrace();
                            }
                        }

                    }
                }
            };
            muc.addMessageListener(myListener);

            PacketListener peopleListener = new PacketListener() {

                @Override
                public void processPacket(Packet packet) {
                    //System.out.println("People PacketData:" + packet.toXML());
                    if (packet.getClass().toString().equalsIgnoreCase(
                            "class org.jivesoftware.smack.packet.Presence")) {
                        Presence p = (Presence) packet;

                        try {
                            System.out.println("Presence from: " + p.getFrom());
                            System.out.println("Presence :" + p.toString());

                            String[] username = p.getFrom().split("/");
                            String t[] = username[0].split("@");
                            //System.out.println("Room:"+t[0]+",msg:"+m.getBody()+",User:"+username[1]);
                            if (p.toString().equalsIgnoreCase("available")) {
                                sendToConfPage(t[0], "** '" + username[1] + "' joined the room **", "", t[1]);
                            } else if (p.toString().equalsIgnoreCase("unavailable")) {
                                sendToConfPage(t[0], "** '" + username[1] + "' left the room **", "", t[1]);
                            }
                        } catch (Exception e) {
                            e.printStackTrace();
                        }
                    }
                }
            };
            muc.addParticipantListener(peopleListener);
            System.out.println("Joined Chat Room :" + room);
        } catch (XMPPException e) {
            e.printStackTrace();
        }
    }

    public MultiUserChat getChatRoomByName(String roomName) {
        for (MultiUserChat chatRoom : myChatRooms) {
            System.out.println("My Room Names:" + chatRoom.getRoom());
            if (chatRoom.getRoom().equalsIgnoreCase(roomName)) {
                return chatRoom;
            }
        }
        return null;
    }

    public void destroyGroupChat(String room) {
        try {
            getChatRoomByName(room).destroy("Finish", "");
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onMessage(ClientSessionChannel arg0,
            org.cometd.bayeux.Message message) {
        Map<String, Object> data = message.getDataAsMap();
        String fromUser = (String) data.get("user");
        String text = (String) data.get("chat");
        System.out.printf("%s: %s%n", fromUser, text);

    }
}
