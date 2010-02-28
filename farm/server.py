#!/usr/bin/python
'''
/*
 * Copyright (c) 2009 William Graeber <william.graeber@swilly.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
'''

from multiprocessing import Queue, Process
import socket
import serial
from serial import SerialException
import logging
from datetime import datetime


class Worker(Process):
    def __init__(self, q):
        self.q = q
        self.logger = logging.getLogger("Hotnest")
        log_handler = logging.FileHandler("./HOTNEST.LOG")
        formatter = logging.Formatter("%(message)s")
        log_handler.setFormatter(formatter)
        self.logger.addHandler(log_handler)
        self.logger.setLevel(logging.INFO)
        super(Worker, self).__init__()
	
    def run(self):
        try:
            self.ser = serial.Serial('/dev/ttyUSB1', 9600)
        except SerialException:
            self.ser = serial.Serial('/dev/ttyUSB0', 9600)
            
        while True:
            l =  self.ser.readline()
            try:
                temps = l.rstrip().split(";")
                temps_out = ""
                for t in temps:
                    temps_out = temps_out + ";%4.2f" % (int(t)*0.0625,)
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                self.logger.info("%s%s" % (timestamp,temps_out))
            except:
                pass
	    
    
class Controller(Process):
    def __init__(self, q):
        self.q = q
        super(Controller, self).__init__()
	
    def run(self):
        HOST = ''
        PORT = 8090

        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, PORT))
        s.listen(1)
        #import pdb
        #pdb.Pdb(stdin=open('/dev/stdin', 'r+'), 
        #stdout=open('/dev/stdout', 'r+')).set_trace()

        while True:
            conn, addr = s.accept()
            print('Connected by ' + str(addr))
            while True:
                msg = conn.recv(1024)
                print "Message received: ", msg
            print('Client disconnected')
            conn.close()
        s.close()


if __name__ == "__main__":
    q = Queue()
    worker = Worker(q).start()
    controller = Controller(q).start()
    
