//
//  HttpServer.swift
//  EnterpriseSwift
//
//  Created by Samuel Kallner on 9/6/15.
//  Copyright © 2015 IBM. All rights reserved.
//

import sys

public class HttpServer {
    
    private static var onceLock : Int = 0
    private static var listenerQueue: Queue?
    private static var clientHandlerQueue: Queue?

    
    public weak var delegate: HttpServerDelegate?
    
    private let spi: HttpServerSpi
    
    private var _port: Int?
    public var port: Int? {
        get { return _port }
    }
    
    private var listenSocket: Socket?
    
    init() {
        spi = HttpServerSpi()
        
        spi.delegate = self
        
        SysUtils.doOnce(&HttpServer.onceLock) {
            HttpServer.listenerQueue = Queue(type: .PARALLEL, label: "HttpServer.listenerQueue")
            HttpServer.clientHandlerQueue = Queue(type: .PARALLEL, label: "HttpServer.clientHAndlerQueue")
        }
    }
    
    
    public func listen(port: Int, notOnMainQueue: Bool=false) {
    
        self._port = port
        self.listenSocket = Socket.create(.INET, type: .STREAM, proto: .TCP)
        
        let queuedBlock = {
            self.spi.spiListen(self.listenSocket, port: self._port!)
        }
        
        if  notOnMainQueue  {
            HttpServer.listenerQueue!.queueAsync(queuedBlock)
        }
        else {
            Queue.queueIfFirstOnMain(HttpServer.listenerQueue!, block: queuedBlock)
        }
    }
}


extension HttpServer : HttpServerSpiDelegate {
    func handleClientRequest(clientSocket: Socket) {
        if  let d = delegate  {
            HttpServer.clientHandlerQueue!.queueAsync() {
                let response = ServerResponse(socket: clientSocket)
                let request = ServerRequest(socket: clientSocket)
                request.parse() { status in
                    switch status {
                    case .Success:
                        d.handleRequest(request, response: response)
                    case .ParsedLessThanRead:
                        print("ParsedLessThanRead")
                    case .UnexpectedEOF:
                        print("UnexpectedEOF")
                    case .InternalError:
                        print("InternalError")
                    }
                }
            }
        }
    }
}


public protocol HttpServerDelegate: class {
    func handleRequest(request: ServerRequest, response: ServerResponse)
}