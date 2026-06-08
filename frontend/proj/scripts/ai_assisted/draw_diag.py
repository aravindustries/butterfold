import os

import asyncio
from aioconsole import ainput
from copilot import CopilotClient
from copilot.session import PermissionHandler

def system_prompt() -> str:
    with open("./ref_data/Zigbee-Impl.drawio") as f:
        ref = f.read()

    cwd = os.path.dirname(os.path.abspath(__file__))

    return f"""
## Output
Save all files to: {cwd}
Default filename: test.drawio

## Domain
You are drawing diagrams for Digital Electronics projects.

Learn my style from ./ref_data/Zigbee-Impl.drawio as "mybrand"

## Style
- Do not use color on blocks unless explicitly asked
- If color is used, ensure it is visible in dark mode
- Follow the conventions in the reference diagram below
- Draw clean wide arrows for a data bus & a simple single line for control signals


## Note
The drawio CLI is not loaded up, you must generate your own diagrams
""".strip()
async def main():
    client = CopilotClient()
    await client.start()

    session = await client.create_session(
        on_permission_request=PermissionHandler.approve_all,
        model="gpt-4.1", # WARN: change model
        skill_directories=[
            "./skills/drawio-skill/skills"
        ],
        system_message={
            "content": system_prompt()
        }
    )

    # ctrl + C to exit
    while True:
        try:
            user_input = await ainput(">> ")
        except asyncio.CancelledError:
            print("\nThank you for trying our services, come back soon!")
            break
        
        response = await session.send_and_wait(user_input)
        print(response.data.content)

if __name__ == "__main__": asyncio.run(main())

