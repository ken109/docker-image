import os
import sys
from twisted.internet import reactor, defer
from twisted.names import client, dns, error, server
from twisted.python import log
from twisted.logger import Logger
import re


class DynamicResolver(object):
    log = Logger()

    def __init__(self, local_domains):
        self.local_domains = local_domains
        self.hosts = []

    def _dynamicResponseRequired(self, query):
        name = query.name.name.decode()
        if query.type == dns.A:
            self.hosts = [domain[0].search(name) for domain in self.local_domains]
            if any(self.hosts):
                self.log.debug(f'Localhost address: {name}')
                return True
            self.log.debug(f'Other host address: {name}')
        else:
            self.log.debug(f'Non type A address: {name}')
        return False

    def _doDynamicResponse(self, query):
        name = query.name.name.decode()
        answer = dns.RRHeader(
            name=name,
            payload=dns.Record_A(
                address=self.local_domains[[i for i, x in enumerate(self.hosts) if x is not None][0]][1]))
        answers = [answer]
        authority = []
        additional = []
        return answers, authority, additional

    def query(self, query, timeout=None):
        if self._dynamicResponseRequired(query):
            return defer.succeed(self._doDynamicResponse(query))
        else:
            return defer.fail(error.DomainError())


def main():
    local_domains = []
    with open('/usr/src/app/hosts.txt', 'r') as f:
        for line in f:
            host = line.split()
            if host[0][0] == '/' and host[0][-1] == '/':
                local_domains.append([re.compile(host[0][1:-1]), host[1]])
            elif host[0][0] == '/' or host[0][-1] == '/':
                exit(2)
            else:
                host[0] = host[0].replace('*', r'[0-9a-zA-Z\-_]*')
                local_domains.append([re.compile(f'^{host[0]}$'), host[1]])

    log.startLogging(sys.stdout)

    factory = server.DNSServerFactory(
        clients=[DynamicResolver(local_domains), client.Resolver(servers=[('8.8.8.8', 53), ('8.8.4.4', 53)])]
    )

    protocol = dns.DNSDatagramProtocol(controller=factory)

    reactor.listenUDP(53, protocol)
    reactor.listenTCP(53, factory)

    reactor.run()


def write_pid(pidfile):
    if not pidfile:
        return False
    pid = os.getpid()
    fp = open(pidfile, 'w')
    try:
        fp.write(str(pid))
        return True
    finally:
        fp.close()


if __name__ == '__main__':
    if write_pid('/var/run/dns.pid') is True:
        raise SystemExit(main())
    else:
        sys.exit(2)
