import os
import time
import uuid

import requests

BASE_URL = os.getenv("BASE_URL", "http://web:5001")


def _wait_for_app(timeout_seconds: int = 60) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        try:
            response = requests.get(f"{BASE_URL}/public", timeout=2)
            if response.status_code == 200:
                return
        except requests.RequestException:
            pass
        time.sleep(1)
    raise TimeoutError(f"Application did not become ready within {timeout_seconds} seconds")


def _register(session: requests.Session, username: str, password: str, email: str) -> requests.Response:
    return session.post(
        f"{BASE_URL}/register",
        data={
            "username": username,
            "email": email,
            "password": password,
            "password2": password,
        },
        timeout=5,
        allow_redirects=True,
    )


def _login(session: requests.Session, username: str, password: str) -> requests.Response:
    return session.post(
        f"{BASE_URL}/login",
        data={"username": username, "password": password},
        timeout=5,
        allow_redirects=True,
    )


def test_auth_flow_register_login_logout() -> None:
    _wait_for_app()

    suffix = uuid.uuid4().hex[:8]
    username = f"int_auth_{suffix}"
    password = "secure123"
    email = f"{username}@example.com"

    session = requests.Session()

    register_response = _register(session, username, password, email)
    assert register_response.status_code == 200
    assert "Sign In" in register_response.text

    login_response = _login(session, username, password)
    assert login_response.status_code == 200
    assert "You were logged in" in login_response.text
    assert f"sign out [{username}]" in login_response.text

    logout_response = session.get(f"{BASE_URL}/logout", timeout=5, allow_redirects=True)
    assert logout_response.status_code == 200
    assert "sign in" in logout_response.text


def test_timeline_visibility_and_follow_unfollow() -> None:
    _wait_for_app()

    suffix = uuid.uuid4().hex[:8]
    user_a = f"int_alice_{suffix}"
    user_b = f"int_bob_{suffix}"
    password = "secure123"

    session_a = requests.Session()
    session_b = requests.Session()

    _register(session_a, user_a, password, f"{user_a}@example.com")
    _register(session_b, user_b, password, f"{user_b}@example.com")

    _login(session_a, user_a, password)
    post_a = session_a.post(
        f"{BASE_URL}/add_message",
        data={"text": f"msg_from_{user_a}"},
        timeout=5,
        allow_redirects=True,
    )
    assert post_a.status_code == 200
    assert "Your message was recorded" in post_a.text

    _login(session_b, user_b, password)
    post_b = session_b.post(
        f"{BASE_URL}/add_message",
        data={"text": f"msg_from_{user_b}"},
        timeout=5,
        allow_redirects=True,
    )
    assert post_b.status_code == 200

    my_timeline_before_follow = session_b.get(f"{BASE_URL}/", timeout=5)
    assert f"msg_from_{user_b}" in my_timeline_before_follow.text
    assert f"msg_from_{user_a}" not in my_timeline_before_follow.text

    follow_response = session_b.get(f"{BASE_URL}/{user_a}/follow", timeout=5, allow_redirects=True)
    assert follow_response.status_code == 200

    my_timeline_after_follow = session_b.get(f"{BASE_URL}/", timeout=5)
    assert f"msg_from_{user_b}" in my_timeline_after_follow.text
    assert f"msg_from_{user_a}" in my_timeline_after_follow.text

    unfollow_response = session_b.get(f"{BASE_URL}/{user_a}/unfollow", timeout=5, allow_redirects=True)
    assert unfollow_response.status_code == 200

    my_timeline_after_unfollow = session_b.get(f"{BASE_URL}/", timeout=5)
    assert f"msg_from_{user_b}" in my_timeline_after_unfollow.text
    assert f"msg_from_{user_a}" not in my_timeline_after_unfollow.text

    public_timeline = session_b.get(f"{BASE_URL}/public", timeout=5)
    assert f"msg_from_{user_a}" in public_timeline.text
    assert f"msg_from_{user_b}" in public_timeline.text
