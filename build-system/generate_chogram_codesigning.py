#!/usr/bin/env python3
# Generates fake provisioning profiles for org.chogram.app from build-system/fake-codesigning.
# The build only needs them to pass the rules_apple checks: AltStore re-signs the IPA on install.
# The output is committed to build-system/chogram-codesigning, re-run this before ExpirationDate.

import datetime
import os
import plistlib
import re
import shutil
import subprocess
import tempfile
import uuid

BASE_PATH = os.path.dirname(os.path.abspath(__file__))
SOURCE_PATH = BASE_PATH + '/fake-codesigning'
DESTINATION_PATH = BASE_PATH + '/chogram-codesigning'

SOURCE_BUNDLE_ID = 'ph.telegra.Telegraph'
DESTINATION_BUNDLE_ID = 'org.chogram.app'

# Matches the notAfter of fake-codesigning/certs/SelfSigned.p12.
EXPIRATION_DATE = datetime.datetime(2030, 10, 29, 17, 0, 0)


def read_profile(path):
    with open(path, 'rb') as file:
        data = file.read()
    match = re.search(rb'<\?xml.*?</plist>', data, re.DOTALL)
    return match.group(0).replace(SOURCE_BUNDLE_ID.encode(), DESTINATION_BUNDLE_ID.encode())


def sign_profile(profile_data, key_path, cert_path, path):
    with tempfile.NamedTemporaryFile(suffix='.plist') as file:
        file.write(profile_data)
        file.flush()
        subprocess.run([
            'openssl', 'cms', '-sign', '-nodetach', '-binary',
            '-signer', cert_path, '-inkey', key_path,
            '-in', file.name, '-outform', 'DER', '-out', path
        ], check=True)


def main():
    if os.path.exists(DESTINATION_PATH):
        shutil.rmtree(DESTINATION_PATH)
    os.makedirs(DESTINATION_PATH + '/profiles')
    shutil.copytree(SOURCE_PATH + '/certs', DESTINATION_PATH + '/certs')

    with tempfile.TemporaryDirectory() as temp_path:
        pem_path = temp_path + '/identity.pem'
        subprocess.run([
            'openssl', 'pkcs12', '-legacy', '-nodes', '-passin', 'pass:',
            '-in', SOURCE_PATH + '/certs/SelfSigned.p12', '-out', pem_path
        ], check=True)

        for file_name in sorted(os.listdir(SOURCE_PATH + '/profiles')):
            profile = plistlib.loads(read_profile(SOURCE_PATH + '/profiles/' + file_name))
            profile['Name'] = profile['Name'].replace('ph.telegra.Telegraph', DESTINATION_BUNDLE_ID)
            profile['UUID'] = str(uuid.uuid4())
            profile['CreationDate'] = datetime.datetime(2026, 10, 31)
            profile['ExpirationDate'] = EXPIRATION_DATE
            profile['TimeToLive'] = (EXPIRATION_DATE - profile['CreationDate']).days
            sign_profile(plistlib.dumps(profile), pem_path, pem_path, DESTINATION_PATH + '/profiles/' + file_name)


if __name__ == '__main__':
    main()
