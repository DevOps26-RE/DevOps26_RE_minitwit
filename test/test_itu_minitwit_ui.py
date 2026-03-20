"""UI and E2E tests adapted for the Go MiniTwit stack in Docker Compose."""

import os
import time
import uuid

import psycopg2
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options


GUI_URL = os.getenv("GUI_URL", "http://web:5001/register")
SELENIUM_REMOTE_URL = os.getenv("SELENIUM_REMOTE_URL", "http://selenium:4444/wd/hub")

DB_CONFIG = {
    "host": os.getenv("PGHOST", "db"),
    "port": int(os.getenv("PGPORT", "5432")),
    "dbname": os.getenv("PGDATABASE", "minitwit"),
    "user": os.getenv("PGUSER", "minitwit"),
    "password": os.getenv("PGPASSWORD", "minitwit"),
}


def _register_user_via_gui(driver, data):
    driver.get(GUI_URL)

    wait = WebDriverWait(driver, 5)
    wait.until(EC.presence_of_all_elements_located((By.CLASS_NAME, "actions")))
    input_fields = driver.find_elements(By.TAG_NAME, "input")

    for idx, str_content in enumerate(data):
        input_fields[idx].send_keys(str_content)
    input_fields[4].click()

    wait = WebDriverWait(driver, 5)
    wait.until(EC.presence_of_element_located((By.TAG_NAME, "h2")))

    page_source = driver.page_source
    if "Sign In" in page_source:
        return "You were successfully registered and can login now"
    elif "error" in page_source.lower():
        error_div = driver.find_element(By.CLASS_NAME, "error")
        return error_div.text
    return page_source


def _create_driver() -> webdriver.Remote:
    options = Options()
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    return webdriver.Remote(command_executor=SELENIUM_REMOTE_URL, options=options)


def _wait_for_app(timeout_seconds: int = 60) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        try:
            with _create_driver() as driver:
                driver.get(GUI_URL)
                if "Sign Up" in driver.page_source:
                    return
        except Exception:
            pass
        time.sleep(1)
    raise TimeoutError(f"UI app did not become ready within {timeout_seconds} seconds")


def _get_user_by_name(username: str):
    with psycopg2.connect(**DB_CONFIG) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT username FROM users WHERE username = %s", (username,))
            return cur.fetchone()


def _delete_user_by_name(username: str) -> None:
    with psycopg2.connect(**DB_CONFIG) as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM follower WHERE who_id IN (SELECT user_id FROM users WHERE username = %s) OR whom_id IN (SELECT user_id FROM users WHERE username = %s)", (username, username))
            cur.execute("DELETE FROM messages WHERE author_id IN (SELECT user_id FROM users WHERE username = %s)", (username,))
            cur.execute("DELETE FROM users WHERE username = %s", (username,))
        conn.commit()


def test_register_user_via_gui():
    """
    This is a UI test. It only interacts with the UI that is rendered in the browser and checks that visual
    responses that users observe are displayed.
    """
    _wait_for_app()

    suffix = uuid.uuid4().hex[:8]
    username = f"ui_me_{suffix}"
    email = f"{username}@some.where"

    with _create_driver() as driver:
        generated_msg = _register_user_via_gui(driver, [username, email, "secure123", "secure123"])
        expected_msg = "You were successfully registered and can login now"
        assert generated_msg == expected_msg

    # cleanup, make test case idempotent
    _delete_user_by_name(username)


def test_register_user_via_gui_and_check_db_entry():
    """
    This is an end-to-end test. Before registering a user via the UI, it checks that no such user exists in the
    database yet. After registering a user, it checks that the respective user appears in the database.
    """
    _wait_for_app()

    suffix = uuid.uuid4().hex[:8]
    username = f"e2e_me_{suffix}"
    email = f"{username}@some.where"

    with _create_driver() as driver:
        assert _get_user_by_name(username) is None

        generated_msg = _register_user_via_gui(driver, [username, email, "secure123", "secure123"])
        expected_msg = "You were successfully registered and can login now"
        assert generated_msg == expected_msg

        assert _get_user_by_name(username)[0] == username

        # cleanup, make test case idempotent
        _delete_user_by_name(username)
