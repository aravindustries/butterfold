import asyncio
from aioconsole import ainput
from copilot import CopilotClient
from copilot.session import PermissionHandler

async def main():
    client = CopilotClient()
    await client.start()

    session = await client.create_session(
        on_permission_request=PermissionHandler.approve_all,
        model="gpt-4.1", # WARN: change model
        skill_directories=[
            "./skills/typst-skills"
        ],
    )

    while True:
        try:
            user_input = await ainput(">> ")
        except asyncio.CancelledError:
            print("\nThank you for trying our services, come back soon!")
            break
        
        response = await session.send_and_wait(user_input)
        print(response.data.content)

    await client.stop()

if __name__ == "__main__": asyncio.run(main())

