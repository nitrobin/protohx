package server.java;

//#if java

import common.Config;
import server.logic.SessionRegistry;
import server.logic.Session;
import server.logic.BakedMsg;
import haxe.io.BytesOutput;
import haxe.io.Bytes;


import java.net.InetSocketAddress;
import java.util.concurrent.Executors;

import org.jboss.netty.bootstrap.ServerBootstrap;
import org.jboss.netty.channel.socket.nio.NioServerSocketChannelFactory;
import org.jboss.netty.channel.ChannelPipeline;
import org.jboss.netty.channel.ChannelPipelineFactory;
import org.jboss.netty.channel.ChannelEvent;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.ExceptionEvent;
import org.jboss.netty.channel.MessageEvent;
import org.jboss.netty.channel.SimpleChannelUpstreamHandler;
import org.jboss.netty.channel.ChannelStateEvent;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffers;
import org.jboss.netty.channel.Channels;

class NettySession extends Session {

    public var channel:Channel;

    public function new(channel:Channel) {
        super();
        this.channel = channel;
    }

    public override function close():Void {
        channel.close();
    }

    public override function bakeMsg(msg:protohx.Message):BakedMsg {
        return new BakedMsg(msg);
    }

    public override function writeMsgBaked(msg:BakedMsg):Void {
        writeMsg(msg.msg);
    }

    public override function writeMsg(msg:protohx.Message):Void {
        try{
            var bytes = msgToFrameBytes(msg);
            channel.write(ChannelBuffers.wrappedBuffer(bytes.getData()));
        }catch(e:Dynamic){
            trace(e);
            #if haxe3
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            #else
            trace(haxe.Stack.toString(haxe.Stack.exceptionStack()));
            #end
        }
    }
    public static function msgToFrameBytes(msg:protohx.Message):haxe.io.Bytes {
        var b = new BytesOutput();
        msg.writeTo(b);
        var data = b.getBytes();

        var res = new BytesOutput();
        res.writeUInt16(data.length);
        res.write(data);
        return res.getBytes();
    }

}

class MainServer {
    var sr:SessionRegistry;

    public function new() {
        sr = new SessionRegistry();
    }

    public static function main() {
        var server = new MainServer();
        trace("Running..");
        server.run("0.0.0.0", Config.DEFAULT_TCP_PORT);
    }

    public function run(host:String, port:Int) /*throws Exception*/ {
        // Configure the server.
        var bootstrap = new ServerBootstrap(
            new NioServerSocketChannelFactory(
            Executors.newCachedThreadPool(),
            Executors.newCachedThreadPool()));

        // Set up the event pipeline factory.
        bootstrap.setPipelineFactory(new ServerPipelineFactory(sr));

        // Bind and start to accept incoming connections.
        bootstrap.bind(new InetSocketAddress(port));
    }
}


class ServerPipelineFactory implements ChannelPipelineFactory {
    var sr:SessionRegistry;
    public function new(sr:SessionRegistry) {
        this.sr = sr;
    }

    public function getPipeline():ChannelPipeline /*throws Exception*/ {
        var p:ChannelPipeline = Channels.pipeline();
        p.addLast("handler", new ServerHandler(sr));
        return p;
    }
}

class ServerHandler extends SimpleChannelUpstreamHandler {
    var sr:SessionRegistry;
    public function new(sr:SessionRegistry) {
        super();
        this.sr = sr;
    }

    @:overload
    @:throws("java.lang.Exception")
    public override function handleUpstream(ctx:ChannelHandlerContext, e:ChannelEvent):Void
    /*throws Exception*/ {
        if (Std.is(e, ChannelStateEvent)) {
            trace(e);
        }
        super.handleUpstream(ctx, e);
    }
    @:overload
    @:throws("java.lang.Exception")
    public override function channelConnected(ctx:ChannelHandlerContext, e:ChannelStateEvent):Void
    /*throws Exception*/ {
        var c = e.getChannel();
        var session = new NettySession(c);
        ctx.setAttachment(session);
        trace("client: " + session.id + " / " + c);
        java.Lib.lock(sr,{sr.sessionConnect(session);0;});
    }

    @:overload
    @:throws("java.lang.Exception")
    public override function channelDisconnected(ctx:ChannelHandlerContext,
                                 e:ChannelStateEvent):Void
    /*throws Exception*/ {
        var session: NettySession = cast ctx.getAttachment();
        if(session!=null){
            trace("client " + Std.string(session.id) + " disconnected");
            java.Lib.lock(sr,{sr.sessionDisconnect(session);0; });
        }
    }

    @:overload
    @:throws("java.lang.Exception")
    public override function messageReceived(ctx:ChannelHandlerContext, e:MessageEvent ) {
        if(Std.is(e.getMessage(), ChannelBuffer)){
            var buffer:ChannelBuffer = cast(e.getMessage(), ChannelBuffer);
            var bytes = haxe.io.Bytes.ofData(buffer.array());
            trace("bytes: "+bytes.length);
            var session: NettySession = cast ctx.getAttachment();
            if(session!=null){
                java.Lib.lock(sr,{sr.sessionData(session, bytes);0;});
            }
        } else {
            trace("WARN: "+ e.getMessage());
        }
    }

    @:overload
    @:throws("java.lang.Exception")
    public override function exceptionCaught(ctx:ChannelHandlerContext, e:ExceptionEvent) {
        trace("Unexpected exception from downstream." + e.getCause());
        e.getChannel().close();
    }
}

//#end

