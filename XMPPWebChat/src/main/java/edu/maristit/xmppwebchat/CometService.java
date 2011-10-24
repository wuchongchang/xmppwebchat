/**
 * Copyright (C) 2011  Adam Hocek. Contact: ahocek@gmail.com,  Udaya K Ghattamaneni. 
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

import java.util.Map;

import org.cometd.bayeux.server.BayeuxServer;
import org.cometd.bayeux.server.ServerChannel;
import org.cometd.bayeux.server.ServerSession;
import org.cometd.server.AbstractService;

public class CometService extends AbstractService {

    String name;

    public CometService(BayeuxServer bayeuxServer, String name) {
        super(bayeuxServer, name);
        ServerChannel sc = bayeuxServer.getChannel("/" + name);
        if (sc != null) {
            sc.remove();
        }
        addService("/" + name, "processMessage");
        this.name = name;
    }

    public void processMessage(ServerSession remote, Map<String, Object> data) {
        remote.deliver(getServerSession(), "/" + name, data, null);
        System.out.println("Got:'" + data + "' in:" + name);
    }
}
