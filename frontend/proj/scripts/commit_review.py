import os
import sys
import subprocess
from pathlib import Path
import readchar

import asyncio
from copilot import CopilotClient
from copilot.session import PermissionHandler

# NOTE: It only works with lazygit as the git cli to add a message also commits it

def system_prompt():
    return """
You are a commit message reviewer. Given a staged diff and a commit message, \
determine if the message adequately describes ALL meaningful changes in the diff.

The staged_commit_msg has the format
<commit summary> (1st line)
<commit description> (2nd line onwards, optional)

Respond with one of:
    OK: <brief reason why the message is sufficient>
    WARN: <what's missing or unclear in the message>

Keep your response succinct.
"""

async def main():
    client = CopilotClient()
    await client.start()

    session = await client.create_session(
        on_permission_request=PermissionHandler.approve_all,
        model="gpt-4.1", # WARN: change model
        system_message={
            "content": system_prompt()
        }
    )

    while True:
        try:
            with open(Path(os.environ.get("PROJECT_ROOT_DIR")) / ".git/LAZYGIT_PENDING_COMMIT") as file:
                staged_commit_msg = file.read()
        except:
            print("It appears you have not written a commit message yet.")
            break

        staging_diff = subprocess.run(
            ["git", "diff", "--cached"],
            capture_output=True,
            text=True
        ).stdout
        if not staging_diff:
            print("No staged changes found.")
            break

        response = await session.send_and_wait(f"{staging_diff=}\n{staged_commit_msg=}")
        print(response.data.content)

        try:
            print("Press any key to re-try...", end="", flush=True)
            if readchar.readchar() == '\x03': raise KeyboardInterrupt
            print("running")
        except KeyboardInterrupt:
            print("\nThank you for trying our services, come back soon!")
            break

    await client.stop()

if __name__ == "__main__": asyncio.run(main())

