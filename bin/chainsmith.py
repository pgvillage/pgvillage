#!/usr/bin/python


"""
Implementation as described here:
https://www.golinuxcloud.com/generate-self-signed-certificate-openssl/#Create_encrypted_password_file_Optional
https://www.golinuxcloud.com/openssl-create-certificate-chain-linux/
https://www.golinuxcloud.com/openssl-create-client-server-certificate/
"""

import os
# import os.path
import random
import socket
import string
import subprocess
import tempfile
import yaml

try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper


class ConfigFile(list):
    """
    configparser does not work with config without a section header. Everything should be under a [ section ].
    But openssl.cnf does have stuff which is not in any section (top).
    Furthermore, it als has values that are not formatted `key = value`, such as
       .include /etc/crypto-policies/back-ends/opensslcnf.config
    For these reasons we don;t use configparser, but rather parse the config ourselves.

    ConfigFile is the main placeholder for all config in a file.
    It is a list of config sections, where every config section is of type ConfigChapter.
    """

    def __init__(self, file):
        super().__init__()
        file = os.path.realpath(os.path.expanduser(file))
        chapter = ConfigChapter('')
        self.append(chapter)
        with open(file) as cf:
            for line in cf:
                line = line.strip()
                if len(line) == 0:
                    chapter.append(ConfigLine(line))
                elif line[0] == '[' and line[-1] == ']':
                    chapter = ConfigChapter(line[1:-2].strip())
                    self.append(chapter)
                else:
                    chapter.append(ConfigLine(line))

    def write(self, file):
        file = os.path.realpath(os.path.expanduser(file))
        with open(file, 'w') as cf:
            cf.write(self.string())

    def string(self):
        return '\n'.join([cc.string() for cc in self])

    def set_chapter(self, new_chapter):
        for i in range(len(self)):
            chapter = self[i]
            if chapter.name() == new_chapter.name():
                self[i] = new_chapter
                return
        self.append(new_chapter)

    def get_chapter(self, name):
        for chapter in self:
            if chapter.name() == name:
                return chapter
        c = ConfigChapter(name)
        self.append(c)
        return c

    def set_key(self, chapter, key, value):
        c = self.get_chapter(chapter)
        k = c.get_key(key)
        k.set_value(value)

    def reset_key(self, chapter, key):
        c = self.get_chapter(chapter)
        c.reset_key(key)


class ConfigChapter(list):
    """
    Every ConfigChapter has a name, and is a list of ConfigLines.
    Like
    ```
    [ chapter1 ]
    key1 = value1
    .include /what/ever/file.config
    ```
    would be a ConfigChapter with name='chapter1' and having 2 ConfigLines (key1..., .include... and an empty list for 
    the last line).
    """
    __name = ""

    def __init__(self, name):
        super().__init__()
        self.__name = name

    def name(self):
        return self.__name

    def string(self):
        ret = []
        if self.__name:
            ret.append('[ {} ]'.format(self.__name))
        ret += [c.string() for c in self]
        return '\n'.join(ret)

    def get_key(self, name):
        for key in self:
            if key.name() == name:
                return key
        k = ConfigLine(name + '=')
        self.append(k)
        return k

    def reset_key(self, name):
        for i in range(len(self)):
            key = self[i]
            if key.name() == name:
                self.pop(i)
                return


class ConfigLine(list):
    """
    Every ConfigLine presents a config line in a config chapter in a config file.
    It just splits it up in `key = value` pairs, unless the first = character is after the first # character
    in which case it is comment.
    As such:
    - an empty line would end up being an empty list
    - a line without = before a # sign would become a list with 1 items
    - a line with = before # character would become a list with 2 elements

    ConfigLine cleans extra spaces for `key=value` lines (into `key = value`), and leaves comments where they are.
    A configLine with 2 elements are key=value lines and key then also is returned with the name() method.
    """

    def __init__(self, line):
        super().__init__()
        if '#' in line and line.find('=') > line.find('#'):
            self.append(line)
        else:
            for part in line.split('=', 2):
                part = part.strip()
                self.append(part)

    def name(self):
        if len(self) > 1:
            return self[0]
        else:
            return ""

    def set_value(self, value):
        key = self[0]
        self.clear()
        self.append(key)
        if value:
            self.append(value)

    def string(self):
        return " = ".join(self)


class TlsSubject(dict):
    """
    TlsSubject is a small helper class to wrap, unwrap and merge tls subjects that have a form of:
       "/C=US/ST=Utah/L=Lehi/O=Your Company, Inc./OU=IT/CN=yourdomain.com"
    """

    def __init__(self, subject):
        super().__init__()
        if isinstance(subject, str):
            for kv in subject.split('/'):
                if '=' in kv:
                    k, v = kv.split('=', 2)
                    self[k] = v
        else:
            for k, v in subject.items():
                self[k] = v

    def string(self):
        return '/' + '/'.join(['{}={}'.format(k, v) for k, v in self.items()])

    def merge(self, other):
        for k, v in other.items():
            self[k] = v

    def clone(self):
        c = TlsSubject('')
        for k, v in self.items():
            c[k] = v
        return c

    def chapter(self):
        c = ConfigChapter('req_distinguished_name')
        for k, v in self.items():
            c.append(ConfigLine('{} = {}'.format(k, v)))
        c.append(ConfigLine(''))
        return c


class TlsPwdAlreadySetException(Exception):
    """
    This exception will be raised the gen_pem_password method is run a second time.
    """
    pass


class TlsCA(dict):
    """
    TlsCA represents a certificate authority, either root or intermediate.
    It just is a placeholder for the folder, directories, config files, etc.
    And it has methods to create all, sign sub certificates, generate private keys, etc.
    if __parent is None, it is a root certificate, if not, it is a intermediate certificate.
    The class can be used to setup a CA store, and use it to sign requests for lower certificates.
    """
    __capath = ''
    __name = ''
    __cert_type = ''
    __configFile = ''
    __PEMFile = ''
    __passwordFile = ''
    __certFile = ''
    __chainFile = ''
    __subject = None
    __parent = None

    def __init__(self, capath, name, cert_type, parent):
        super().__init__()
        self.__capath = capath
        self.__name = name
        self.__cert_type = cert_type
        self.__configFile = os.path.join(capath, 'config', 'ca.cnf')
        self.__PEMFile = os.path.join(capath, 'private', 'cakey.pem')
        self.__passwordFile = os.path.join(capath, 'private', 'capass.enc')
        self.__certFile = os.path.join(capath, 'certs', 'cacert.pem')
        self.__chainFile = os.path.join(capath, 'certs', 'ca-chain-bundle.cert.pem')
        if parent is not None:
            self.set_subject(parent.__subject)
            self.__parent = parent
        for subfolder in ['.', 'config', 'certs', 'csr', 'newcerts', 'private']:
            path = os.path.realpath(os.path.expanduser(os.path.join(capath, subfolder)))
            if not os.path.exists(path):
                os.makedirs(path)
        serial_file = os.path.join(capath, 'serial')
        if not os.path.exists(serial_file):
            with open(serial_file, 'w') as serial:
                serial.write('01')
        index_file = os.path.join(capath, 'index.txt')
        if not os.path.exists(index_file):
            open(index_file, 'w')

    def name(self):
        return self.__name

    def gen_pem_password(self, password=None):
        if os.path.exists(self.__passwordFile):
            raise TlsPwdAlreadySetException(self.__passwordFile, "already exists, not replacing")
        if not password:
            password = ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(18))
            print('using a random password for', self.name(), 'pem: ', password)
        # This creates a tempfile, writes the password to it, creates the enc file and removes the tempfile
        # as atomic as possible
        with tempfile.NamedTemporaryFile(mode='w') as tmpFile:
            tmpFile.write(password)
            tmpFile.flush()
            print("Running openssl genrsa for", self.name())
            args = ['openssl', 'enc', '-aes256', '-salt', '-in', tmpFile.name, '-out', self.__passwordFile, '-pass',
                    'file:'+tmpFile.name]
            subprocess.run(args)

    def set_subject(self, subject):
        self.__subject = subject.clone()
        self.__subject['CN'] = self.name()

    def subject(self):
        return self.__subject.clone()

    def path(self):
        return self.__capath

    def configfile(self):
        return self.__configFile

    def gen_ca_cnf(self):
        if self.__parent is not None:
            cf = ConfigFile(self.__parent.configfile())
            cf.set_key('CA_default', 'dir', self.__capath)
            cf.set_key('CA_default', 'policy', 'policy_anything')
            cf.set_key('CA_default', 'default_days', '3650')
            # req_attributes contains _min and _max values that help with prompt=yes, but not with prompt=no
            # so resetting to empty chapter
            cf.set_chapter(ConfigChapter('req_attributes'))
        else:
            cf = ConfigFile('/etc/pki/tls/openssl.cnf')
            cf.set_key('req', 'prompt', 'no')
            # cf.set_key('', 'HOME', '.')
            # cf.set_key('', 'RANDFILE', '$ENV::HOME/.rnd')
            # cf.set_key('', 'oid_section', 'new_oids')
            if os.path.exists('/etc/crypto-policies/back-ends/opensslcnf.config'):
                # seems to have something to do with FIPS mode on RH8. For more info see
                # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/security_hardening/using-the-system-wide-cryptographic-policies_security-hardening
                cf.set_key('', 'openssl_conf', 'default_modules')
                cf.set_key('default_modules', 'ssl_conf', 'ssl_module')
                cf.set_key('ssl_module', 'system_default', 'crypto_policy')
                cf.set_key('crypto_policy', '.include /etc/crypto-policies/back-ends/opensslcnf.config', '')

            cf.set_key('CA_default', 'dir', self.__capath)
            # lifetime of ca is 10 years
            cf.set_key('CA_default', 'default_days', '3650')
            # cf.set_key('CA_default', 'policy', 'policy_match')

            cf.set_key('req', 'default_bits', '4096')

            intermediate_chapter = ConfigChapter('v3_intermediate_ca')
            intermediate_chapter.append(ConfigLine('subjectKeyIdentifier = hash'))
            intermediate_chapter.append(ConfigLine('authorityKeyIdentifier = keyid:always,issuer'))
            intermediate_chapter.append(ConfigLine('basicConstraints = critical, CA:true, pathlen:0'))
            intermediate_chapter.append(ConfigLine('keyUsage = critical, digitalSignature, cRLSign, keyCertSign'))
            intermediate_chapter.append(ConfigLine(''))
            cf.set_chapter(intermediate_chapter)

            cf.set_key('v3_ca', 'basicConstraints', 'critical,CA:true')

        # Generic config for both CA and intermediates
        cf.set_chapter(self.__subject.chapter())
        cf.set_key('CA_default', 'certificate', self.__certFile)
        cf.set_key('CA_default', 'private_key', self.__PEMFile)

        if self.__cert_type in ['client', 'server']:
            cf.set_key('usr_cert', 'basicConstraints', 'CA:FALSE')
            cf.set_key('usr_cert', 'subjectKeyIdentifier', 'hash')
        if self.__cert_type == 'client':
            cf.set_key('usr_cert', 'nsCertType', 'client, email')
            cf.set_key('usr_cert', 'nsComment', '"OpenSSL Generated Client Certificate"')
            cf.set_key('usr_cert', 'authorityKeyIdentifier', 'keyid,issuer')
            cf.set_key('usr_cert', 'keyUsage', 'critical, nonRepudiation, digitalSignature, keyEncipherment')
            cf.set_key('usr_cert', 'extendedKeyUsage', 'clientAuth, emailProtection')
        elif self.__cert_type == 'server':
            cf.set_key('usr_cert', 'nsCertType', 'server')
            cf.set_key('usr_cert', 'nsComment', '"OpenSSL Generated Server Certificate"')
            cf.set_key('usr_cert', 'authorityKeyIdentifier', 'keyid,issuer:always')
            cf.set_key('usr_cert', 'keyUsage', 'critical, digitalSignature, keyEncipherment')
            cf.set_key('usr_cert', 'extendedKeyUsage', 'serverAuth')

        print('writing config to', self.__configFile)
        cf.write(self.__configFile)

    def gen_ca_pem(self):
        try:
            self.gen_pem_password()
        except TlsPwdAlreadySetException:
            # This is just a precaution to use a random password if it was not yet set, so if it is, that is totally
            # cool...
            pass

        print("Running openssl genrsa for", self.name())
        args = ['openssl', 'genrsa', '-des3', '-passout', 'file:' + self.__passwordFile, '-out', self.__PEMFile, '4096']
        subprocess.run(args, cwd=self.__capath, check=True)
        self.verify_pem()

    def verify_pem(self):
        print("Running openssl rsa for", self.name())
        args = ['openssl', 'rsa', '-noout', '-text', '-in', self.__PEMFile, '-passin', 'file:' + self.__passwordFile]
        subprocess.run(args, cwd=self.__capath, check=True)

    def create_ca_cert(self):
        self.gen_ca_cnf()
        self.gen_ca_pem()
        print("Running openssl req for", self.name())
        if self.__parent is None:
            print(self.__subject.string())
            args = ['openssl', 'req', '-new', '-x509', '-days', '3650', '-subj', self.__subject.string(), '-passin',
                    'file:' + self.__passwordFile, '-config', self.__configFile, '-extensions', 'v3_ca', '-key',
                    self.__PEMFile, '-out', self.__certFile]
            subprocess.run(args, cwd=self.__capath, check=True)
        else:
            csr_path = os.path.join(self.__capath, 'csr', 'intermediate.csr.pem')
            args = ['openssl', 'req', '-new', '-sha256', '-subj', self.__subject.string(), '-config', self.__configFile,
                    '-passin', 'file:' + self.__passwordFile, '-key', self.__PEMFile, '-out', csr_path]
            subprocess.run(args, cwd=self.__capath, check=True)
            self.__parent.sign_intermediate_csr(csr_path, self.__certFile)
        self.verify_ca_cer()
        self.write_chain()

    def sign_intermediate_csr(self, csr, cert):
        print("Running openssl ca for", self.name())
        args = ['openssl', 'ca', '-config', self.__configFile, '-extensions', 'v3_intermediate_ca', '-days', '2650',
                '-notext', '-batch', '-passin', 'file:' + self.__passwordFile, '-in', csr, '-out', cert]
        subprocess.run(args, cwd=self.__capath, check=True)

    def sign_cert_csr(self, ext_conf, csr_path, cert_path):
        # openssl x509 -req -days 3650 -in tls/int_server/csr/server1.csr -signkey tls/int_server/private/cakey.pem -out tls/int_server/certs/server1.pem -extfile tls/int_server/config/req_server1.cnf -extensions v3_req -passin file:/host/tls/int_server/private/capass.enc
        print("Running openssl x509 req for", self.name())
        if self.__cert_type == 'client':
            args = ['openssl', 'x509', '-req', '-in', csr_path, '-passin', 'file:' + self.__passwordFile, '-CA',
                    self.__chainFile, '-CAkey', self.__PEMFile, '-out', cert_path, '-CAcreateserial', '-days', '365',
                    '-sha256']
        elif self.__cert_type == 'server':
            args = ['openssl', 'x509', '-req', '-in', csr_path, '-passin', 'file:' + self.__passwordFile, '-CA',
                    self.__chainFile, '-CAkey', self.__PEMFile, '-out', cert_path, '-CAcreateserial', '-days', '365',
                    '-sha256', '-extfile', ext_conf, '-extensions', 'v3_req']
        else:
            raise Exception('Unknown intermediate type')
        print(args)
        subprocess.run(args, cwd=self.__capath, check=True)

    def verify_ca_cer(self):
        print("Running openssl x509 for", self.name())
        args = ['openssl', 'x509', '-noout', '-text', '-in', 'certs/cacert.pem']
        subprocess.run(args, cwd=self.__capath, check=True)

    def get_cert(self):
        with open(self.__certFile) as crt:
            return crt.read()

    def get_chain(self):
        s = self.get_cert()
        if s[-1] != '\n':
            s += '\n'
        if self.__parent is not None:
            s += self.__parent.get_chain()
        return s

    def get_certs(self):
        certs = {}
        certs['chain'] = self.get_chain()
        for name, cert in self.items():
            certs[name] = cert.get_cert()
        return certs

    def get_pem(self):
        with open(self.__PEMFile) as pem:
            return pem.read()

    def get_pems(self):
        pems = {}
        pems[self.name()] = self.get_pem()
        for name, cert in self.items():
            pems[name] = cert.get_pem()
        return pems

    def write_chain(self):
        with open(self.__chainFile, 'w') as chainfile:
            chainfile.write(self.get_chain())

#    def verify_chain(self):
#        args = ['openssl', 'verify', '-CAfile', self.__certFile, 'intermediate/certs/ca-chain-bundle.cert.pem']
#        subprocess.run(args, cwd=self.__capath, check=True)
#
    def create_int(self, name, cert_type):
        if self.__parent is not None:
            raise Exception("Creating an intermediate on an intermediate is currently not a feature...")
        if name in self:
            return self[name]
        int_path = os.path.join(self.__capath, 'int_' + name)
        int_ca = TlsCA(int_path, name, cert_type, self)
        int_ca.create_ca_cert()
        # For a root CA, all intermediates are stored in the object
        self[name] = int_ca
        return int_ca

    def create_cert(self, san):
        if not san:
            return
        name = san[0]
        if self.__parent is None:
            raise Exception("Creating a certificate signed by a root CA is currently not a feature...")
        if name in self:
            return self[name]
        # For an intermediate CA, all certs are stored in the object itself
        cert = TlsCert(san, self.__subject.clone(), self)
        self[name] = cert
        return cert


class TlsCert:
    """
    TlsCert represents a certificate to be handed out. This could be a client certificate or a server certificate.
    It works together with its parent (typically a intermediate ca) for signing the csr.
    """
    __name = ""
    __parent = None
    __PEMFile = ""
    __SAN = None
    __CSRPath = ""
    __certFile = ""
    __subject = ""
    __configFile = ""

    def __init__(self, san, subject, parent):
        if not san:
            raise Exception('cannot create TlsCert without at least one name in SAN list')
        name = san[0]
        self.__name = name
        self.__parent = parent
        self.__SAN = san
        self.__subject = subject
        self.__subject['CN'] = name

        path = parent.path()
        self.__PEMFile = os.path.join(path, 'private', name + '.key.pem')
        self.__CSRPath = os.path.join(path, 'csr', name + '.csr')
        self.__certFile = os.path.join(path, 'certs', name + '.pem')
        self.__configFile = os.path.join(path, 'config', 'req_' + name + '.cnf')

        self.gen_pem()
        self.gen_cnf()
        self.gen_cert()

    def name(self):
        return self.__name

    def gen_pem(self):
        args = ['openssl', 'genrsa', '-out', self.__PEMFile, '4096']
        subprocess.run(args, check=True)
        self.verify_pem()

    def verify_pem(self):
        args = ['openssl', 'rsa', '-noout', '-text', '-in', self.__PEMFile]
        subprocess.run(args, check=True)

    def gen_cnf(self):
        cf = ConfigFile(self.__parent.configfile())
        cf.set_key('req', 'req_extensions', 'v3_req')
        # Generic config for both CA and intermediates
        cf.set_chapter(self.__subject.chapter())

        cf.set_key('v3_req', 'keyUsage', 'keyEncipherment, dataEncipherment')
        cf.set_key('v3_req', 'extendedKeyUsage', 'serverAuth')

        if len(self.__SAN) > 1:
            cf.set_key('v3_req', 'subjectAltName', '@alt_names')
            for i in range(len(self.__SAN)):
                if i == 0:
                    # san[0] is already set as CommonName
                    continue
                cf.set_key('alt_names', 'DNS.'+str(i), self.__SAN[i])

        print('writing config to', self.__configFile)
        cf.write(self.__configFile)

    def create_csr(self):
        # openssl req -new -out company_san.csr -newkey rsa:4096 -nodes -sha256 -keyout company_san.key.temp -config
        # req.conf
        # # Converteer de key naar PKCS#1
        # openssl rsa -in company_san.key.temp -out company_san.key
        # # Zet de CSR in leesbaar formaat in een file ernaast
        # openssl req -text -noout -verify -in company_san.csr > company_san.csr.txt
        args = ['openssl', 'req', '-new', '-subj', self.__subject.string(), '-key', self.__PEMFile, '-out',
                self.__CSRPath, '-config', self.__configFile]
        subprocess.run(args, check=True)
        self.verify_csr()

    def verify_csr(self):
        args = ['openssl', 'req', '-noout', '-text', '-in', self.__CSRPath]
        subprocess.run(args, check=True)

    def gen_cert(self):
        self.create_csr()
        self.__parent.sign_cert_csr(self.__configFile, self.__CSRPath, self.__certFile)
        self.verify_cert()

    def verify_cert(self):
        args = ['openssl', 'x509', '-noout', '-text', '-in', self.__certFile]
        subprocess.run(args, check=True)

    def get_cert(self):
        with open(self.__certFile) as crt:
            return crt.read()

    def get_pem(self):
        with open(self.__PEMFile) as pem:
            return pem.read()


def readConfig():
    configFile = os.environ.get('CHAINSMITH_CONFIG', './config/chainsmith.yml')
    config = yaml.load(open(configFile), Loader=Loader)
    return config


def hostInfoFromInventory(hostsfile):
    try:
        groups = yaml.load(open(hostsfile).read())
    except Exception as e:
        raise Exception('could not open', hostsfile, e)
    hosts = []
    try:
        for _, groupinfo in groups['all']['children'].items():
            try:
                hosts += [ host for host in groupinfo['hosts']]
            except KeyError:
                continue
    except KeyError:
        raise Exception('missing all>children in '+hostsfile)
    if not hosts:
        raise Exception('no groups with hosts in all>children in '+hostsfile)
    return hosts

    
def main():
    config = readConfig()
    certs = {}
    pems = {}
    subject = TlsSubject(config.get('subject', 
        "C=NL/postalCode=3721 MA, ST=Utrecht, L=Bilthoven/street=Antonie v Leeuwenhoekln 9, "
        "O=Rijksinstituut voor Volksgezondheid en Milieu (RIVM), OU=Postgres bouwblok, CN=postgres.rivm.nl"))
    tmpdir = config.get('tmpdir', os.environ.get('CHAINSMITH_TMPPATH', ''))
    if not tmpdir:
        tmpdir = tempfile.mkdtemp()
    root = TlsCA(os.path.join(tmpdir, 'tls'), subject.get('CN', 'postgres'), 'ca', None)
    root.set_subject(subject)
    root.create_ca_cert()
    for intermediate in config['intermediates']:
        if 'servers' in intermediate:
            intermediate_server = root.create_int(intermediate['name'], 'server')
            servers = intermediate['servers']
            hostsfile = intermediate.get('environment', os.environ.get('CHAINSMITH_ENV', ''))
            if hostsfile:
                for server in hostInfoFromInventory(hostsfile):
                    if server in servers:
                        continue
                    ip_address = socket.gethostbyname(server)
                    servers[server] = [ip_address]
            for name, alts in servers.items():
                srvr = [ name ] + alts
                intermediate_server.create_cert(srvr)
            certs[intermediate['name']] = intermediate_server.get_certs()
            pems[intermediate['name']] = intermediate_server.get_pems()
        elif 'clients' in intermediate:
            intermediate_client = root.create_int(intermediate['name'], 'client')
            for clnt in intermediate['clients']:
                intermediate_client.create_cert([clnt])
            certs[intermediate['name']] = intermediate_client.get_certs()
            pems[intermediate['name']] = intermediate_client.get_pems()
        else:
            raise Exception('intermediate of unknown type. Either specify "clients" or "servers"', intermediate)

    certspath =  config.get('certspath', os.environ.get('CHAINSMITH_CERTSPATH', 'certs.yml'))
    with open(certspath, 'w') as certsfile:
        certsfile.write('---\n')
        certsfile.write(yaml.dump({ 'certs': certs } , Dumper=Dumper, default_flow_style=False, default_style='|'))

    pemspath = config.get('pemspath', os.environ.get('CHAINSMITH_PEMSPATH', 'pems.yml'))
    with open(pemspath, 'w') as pemsfile:
        pemsfile.write('---\n')
        pemsfile.write(yaml.dump( { 'certs_keys': pems }, Dumper=Dumper, default_flow_style=False, default_style='|'))


if __name__ == "__main__":
    main()
