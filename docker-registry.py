import argparse
import requests
import curses

# Default Docker Registry URL
REGISTRY_URL = "<Modify>"

def list_repositories():
    response = requests.get(f"https://{REGISTRY_URL}/v2/_catalog")
    response.raise_for_status()
    repos = response.json().get("repositories", [])
    return repos

def list_tags(repository):
    response = requests.get(f"https://{REGISTRY_URL}/v2/{repository}/tags/list")
    response.raise_for_status()
    tags = response.json().get("tags", [])
    return tags

def get_manifest(repository, tag):
    response = requests.get(f"https://{REGISTRY_URL}/v2/{repository}/manifests/{tag}")
    response.raise_for_status()
    manifest = response.json()
    return manifest

def delete_image(repository, tag=None, digest=None):
    if tag:
        response = requests.get(f"https://{REGISTRY_URL}/v2/{repository}/manifests/{tag}")
        response.raise_for_status()
        digest = response.headers.get("Docker-Content-Digest")
    if digest:
        response = requests.delete(f"https://{REGISTRY_URL}/v2/{repository}/manifests/{digest}")
        response.raise_for_status()
        return response.status_code == 202
    return False

def curses_main(stdscr):
    stdscr.clear()
    stdscr.addstr(0, 0, "Docker Registry CLI")
    stdscr.addstr(1, 0, "1. List all repositories and tags")
    stdscr.addstr(2, 0, "2. List tags for a specific repository")
    stdscr.addstr(3, 0, "3. Get manifest for an image")
    stdscr.addstr(4, 0, "4. Delete an image")
    stdscr.addstr(5, 0, "5. Delete all images in a repository")
    stdscr.addstr(6, 0, "6. Quit")
    
    while True:
        stdscr.refresh()
        key = stdscr.getch()
        
        if key == ord('1'):
            repos = list_repositories()
            stdscr.clear()
            stdscr.addstr(0, 0, "Repositories:")
            for i, repo in enumerate(repos, start=1):
                stdscr.addstr(i, 0, repo)
            stdscr.addstr(len(repos) + 1, 0, "Press any key to return to menu.")
            stdscr.getch()
            stdscr.clear()
        elif key == ord('2'):
            stdscr.clear()
            stdscr.addstr(0, 0, "Enter repository name: ")
            curses.echo()
            repo = stdscr.getstr().decode("utf-8")
            curses.noecho()
            tags = list_tags(repo)
            stdscr.clear()
            stdscr.addstr(0, 0, f"Tags for {repo}:")
            for i, tag in enumerate(tags, start=1):
                stdscr.addstr(i, 0, tag)
            stdscr.addstr(len(tags) + 1, 0, "Press any key to return to menu.")
            stdscr.getch()
            stdscr.clear()
        elif key == ord('3'):
            stdscr.clear()
            stdscr.addstr(0, 0, "Enter repository name: ")
            curses.echo()
            repo = stdscr.getstr().decode("utf-8")
            stdscr.addstr(1, 0, "Enter tag name: ")
            tag = stdscr.getstr().decode("utf-8")
            curses.noecho()
            manifest = get_manifest(repo, tag)
            stdscr.clear()
            stdscr.addstr(0, 0, f"Manifest for {repo}:{tag}:")
            stdscr.addstr(1, 0, str(manifest))
            stdscr.addstr(2, 0, "Press any key to return to menu.")
            stdscr.getch()
            stdscr.clear()
        elif key == ord('4'):
            stdscr.clear()
            stdscr.addstr(0, 0, "Enter repository name: ")
            curses.echo()
            repo = stdscr.getstr().decode("utf-8")
            stdscr.addstr(1, 0, "Enter tag name: ")
            tag = stdscr.getstr().decode("utf-8")
            curses.noecho()
            success = delete_image(repo, tag)
            stdscr.clear()
            if success:
                stdscr.addstr(0, 0, f"Image {repo}:{tag} deleted successfully.")
            else:
                stdscr.addstr(0, 0, f"Failed to delete image {repo}:{tag}.")
            stdscr.addstr(1, 0, "Press any key to return to menu.")
            stdscr.getch()
            stdscr.clear()
        elif key == ord('5'):
            stdscr.clear()
            stdscr.addstr(0, 0, "Enter repository name: ")
            curses.echo()
            repo = stdscr.getstr().decode("utf-8")
            curses.noecho()
            tags = list_tags(repo)
            for tag in tags:
                delete_image(repo, tag)
            stdscr.clear()
            stdscr.addstr(0, 0, f"All images in {repo} deleted successfully.")
            stdscr.addstr(1, 0, "Press any key to return to menu.")
            stdscr.getch()
            stdscr.clear()
        elif key == ord('6'):
            break
        else:
            stdscr.addstr(7, 0, "Invalid selection. Please try again.")
            
if __name__ == "__main__":
    curses.wrapper(curses_main)
