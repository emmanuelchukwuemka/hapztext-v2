from django.contrib.auth.hashers import check_password, make_password


def hash_password(password: str) -> str:
    return make_password(password)


def password_check(raw_password: str, hashed_password: str) -> bool:
    return check_password(raw_password, hashed_password)


def validate_password(password: str, password_confirm: str) -> None:
    if password != password_confirm:
        raise ValueError("Passwords do not match.")
