# Add Homelab App

Add a new homelab application to the `private_apps/` directory following the existing Docker stack pattern.

## Instructions

1. **Ask for required information:**
   - App name (will be used for directory and container name)
   - GitHub repository URL (optional, for reference)

2. Fetch related information from online
   - Docker image (full image name with tag, e.g., `owner/image:latest`)
   - Port mapping (if needed, format: `host:container`), check all the existing apps to make sure that the port isn't already in use

3. **Create directory structure:**
   - Create `private_apps/<app-name>/` directory
   - All new files should have private permissions (600 for files)

4. **Create docker-compose.yaml with this structure:**

```yaml
services:
    <app-name>:
        container_name: <app-name>
        image: <docker-image>
        restart: always
        network_mode: bridge
        ports:
            - <host-port>:<container-port>
        volumes:
            - <app-name>_data:/path/to/data
        environment:
            TZ: "Europe/Amsterdam"
volumes:
    <app-name>_data:
        name: <app-name>_data
```

5. **Follow these patterns:**
   - **Container name:** Same as app name
   - **Restart policy:** Always use `restart: always`
   - **Network mode:** Use `bridge` unless the app specifically requires `host` mode
   - **Volumes:** Create named volumes with pattern `<app-name>_<purpose>` (e.g., `n8n_data`, `babybuddy_config`)
   - **Environment:** Only include `TZ: "Europe/Amsterdam"` by default
   - **DO NOT add** app-specific environment variables unless explicitly requested
   - **DO NOT copy** environment variables from other apps (like PUID, PGID, CSRF_TRUSTED_ORIGINS) unless needed

6. **Volume configuration:**
   - If the app needs persistent storage, define the volume path based on the app's documentation
   - If unsure about the volume path, ask the user or check the GitHub repo's docker-compose example
   - Volume name should follow pattern: `<app-name>_<purpose>` (e.g., `data`, `config`)

7. **Special cases:**
   - If the app requires `host` network mode, omit the `ports:` section
   - If the app doesn't need persistent storage, omit the `volumes:` section entirely
   - If the app needs additional environment variables, ask the user first

8. **After creating the files:**
   - Display the created docker-compose.yaml for review
   - Remind the user that the app will be deployed on homelab machines (hostname prefix `homelab-*`)
   - Provide basic docker-compose commands:
     ```bash
     cd ~/apps/<app-name>
     docker-compose up -d      # Start the service
     docker-compose logs -f    # View logs
     docker-compose down       # Stop the service
     ```

## Example Output

After creating the app structure, show:
- Created file path: `private_apps/<app-name>/docker-compose.yaml`
- Contents of the docker-compose.yaml
- Deployment instructions
- Note about chezmoi apply needed to sync to homelab

## Important Reminders

- Keep it minimal - only add what's necessary
- Don't copy configurations from other apps
- Ask before adding environment variables beyond TZ
- Follow the naming conventions strictly
- Ensure proper file permissions (private)
