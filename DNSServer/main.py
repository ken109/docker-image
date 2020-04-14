from twisted.internet import reactor, defer
from twisted.names import client, dns, error, server
import re


class DynamicResolver(object):
    def _dynamicResponseRequired(self, query):
        name = query.name.name.decode()
        if query.type == dns.A:
            if re.search(r'^[^.]*$', name) or re.search(r'\.localhost$', name):
                print(f'Localhost address: {name}')
                return True
            print(f'Other host address: {name}')
        else:
            print(f'Non type A address: {name}')
        return False

    def _doDynamicResponse(self, query):
        name = query.name.name.decode()
        answer = dns.RRHeader(
            name=name,
            payload=dns.Record_A(address='127.0.0.1'))
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
    factory = server.DNSServerFactory(
        clients=[DynamicResolver(), client.Resolver(servers=[('8.8.8.8', 53), ('8.8.4.4', 53)])]
    )

    protocol = dns.DNSDatagramProtocol(controller=factory)

    reactor.listenUDP(53, protocol)
    reactor.listenTCP(53, factory)

    reactor.run()


if __name__ == '__main__':
    raise SystemExit(main())
