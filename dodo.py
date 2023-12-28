from doit.tools import Interactive, title_with_actions


def cmd(command: str, **kwargs):
    """
    Helper function to create a task that runs a shell command.
    """
    return {
        # "Interactive" runs without capturing output, passing through
        # colored output.
        "actions": [Interactive(command)],
        # Show the command in the output.
        "title": title_with_actions,
        **kwargs,
    }


def task_check():
    """run checks against the flake without building"""
    return cmd("nix flake check --no-build")


def task_up():
    """
    update `flake.lock` and commit
    """
    return cmd("nix flake update --commit-lock-file")
