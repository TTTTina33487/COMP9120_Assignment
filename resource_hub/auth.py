"""Credential checks for the explicitly configured prototype account."""
import hashlib
import secrets

from werkzeug.security import check_password_hash


DEFAULT_USERNAME = "560601108"
# Hash of the user-requested demonstration password, never the plaintext value.
DEFAULT_PASSWORD_HASH = (
    "scrypt:32768:8:1$t5cpbxQgm7PyuBoP$"
    "daf217dc1bc47fce57e7bf3709487846cfad6145e5926d7288f486b46e195685bb"
    "72bc5d33051411debd6465c3df59e3bcfb52de1d5314c487e56a4d23a89be9"
)
DEFAULT_IDENTITIES = ("student:1", "coordinator:1")


def credentials_match(config, username, password):
    if len(username) > 80 or len(password) > 1024:
        return False
    # Check the hash even for an unknown username; do not disclose which field failed.
    password_valid = check_password_hash(config["DEMO_PASSWORD_HASH"], password)
    username_valid = secrets.compare_digest(username.encode("utf-8"), config["DEMO_USERNAME"].encode("utf-8"))
    return password_valid and username_valid


def session_marker(config):
    """Invalidate existing sessions when the configured credentials change."""
    material = config["DEMO_USERNAME"] + "\0" + config["DEMO_PASSWORD_HASH"]
    return hashlib.sha256(material.encode("utf-8")).hexdigest()
