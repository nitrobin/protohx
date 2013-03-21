Protohx is cross-platform haxe implementation of "Google Protocol Buffers". 
This is Haxe port of ActionScript3 protoc plugin "protoc-gen-as3".

WARNING: This project is still in alpha. Be careful for production using.

## See also
    * https://code.google.com/p/protobuf/
    * https://code.google.com/p/protoc-gen-as3/

## Supported Features
### This functionality ported from "protoc-gen-as3"
    * All basic types  (int, int64, string, bytes, bool)
    * Nested messages
    * Enumerations (as integer)
    * Packed and non-packed repeated fields
    * Extensions (converted to optional fields with "ext_" prefix)

## Tested targets 
    * flash
    * neko 2.0
    * cpp (linux32, win32, android)
    * js (node.js, phantomjs)
    * java


## System requirements
    * haxe 3
    * neko 2.0+ 
    * protoc 2.4.0+ (or 2.5.0+ for generation java sources for test-ipc)
    * java 
    * ant (for build plugin from sources)


## How to install
    1) install protohx
         $ haxelib install protohx
       or
         $ haxelib git protohx https://github.com/nitrobin/protohx
    2) install protoc into system PATH
       * Windows: 
           Download https://protobuf.googlecode.com/files/protoc-2.5.0-win32.zip
           Unpack and add protoc.exe location to system %PATH%
       * Ubuntu:
           $ sudo aptitude install protobuf-compiler
       * Other:
           Download source code from https://code.google.com/p/protobuf/downloads/list
           Unpack and make && make install.
       * NOTE:
           You also can set custom protoc executable with "setup-protoc"
               $ haxelib run protohx setup-protoc PROTOC_2_5_0_PATH 
           For example:
               $ haxelib run protohx setup-protoc /home/user/opt/protobuf-2.5.0/src/protoc


## How to use
    1) create empty json config file in project directory with "config"
        $ haxelib run protohx config protohx.json
        Change and save protohx.json 
        // File: samples/test-core/protohx.json
        {
            "protoPath": "proto",
            "protoFiles": [
                "proto/test.proto",
                "proto/google/protobuf/compiler/plugin.proto",
                "proto/google/protobuf/descriptor.proto"
            ],
            "cleanOut": true,
            "haxeOut": "out/src-gen",
            "javaOut": null
        }
        Parameters:
            protoPath - base path for import directive in proto files;
            protoFiles - list of files for code generation;
            haxeOut/javaOut - path for generated sources (add it in project classpath);
            cleanOut - if 'true' clean output directories before code generation.
    
    2) write proto files
    3) genearate haxe sources:
          $ haxelib run protohx generate protohx.json
    4) add "out/src-gen" (see param: haxeOut) directory in project classpath


## Notes
    Protohx project urls: 
        * https://github.com/nitrobin/protohx
        * https://bitbucket.org/nitrobin/protohx

    This project consists from follow parts:
        * tools/plugin - protoc plugin for generating haxe sources;
        * tools/run - haxelib runner. Generate haxe and a java sources by json config in project directory;
        * protohx - library sources. Pure-haxe port of main parts originally ActionScrip3 code from protoc-gen-as3;
        * samples/01-core - unit tests;
        * samples/02-ipc - java-to-neko and neko-to-java intercommunication test.
            NOTE: Install protoc 2.5.0 via "haxelib run protohx setup-protoc PROTOC_2_5_0_PATH" before building java part of this test.
        * samples/03-network - complete client-server example.
           build/run node.js server:
                haxe build-server-js.hxml
           or neko serer:
                haxe build-server-neko.hxml
           and build/run flash client:
                haxe build-client-flash.hxml
           or
                nme test (flash|linux|android)
