#include "cache.h"
#include "strbuf.h"
#include "run-command.h"
#include "sigchain.h"

#ifndef DEFAULT_EDITOR
#define DEFAULT_EDITOR "vi"
#endif

const char *git_editor(void)
{
	const char *editor = getenv("GIT_EDITOR");
	const char *terminal = getenv("TERM");
	int terminal_is_dumb = !terminal || !strcmp(terminal, "dumb");

	if (!editor && editor_program)
		editor = editor_program;
	if (!editor && !terminal_is_dumb)
		editor = getenv("VISUAL");
	if (!editor)
		editor = getenv("EDITOR");

	if (!editor && terminal_is_dumb)
		return NULL;

	if (!editor)
		editor = DEFAULT_EDITOR;

	return editor;
}

int launch_editor(const char *path, struct strbuf *buffer, const char *const *env)
{
	const char *editor = git_editor();

	if (!editor)
		return error("Terminal is dumb, but EDITOR unset");

	if (strcmp(editor, ":")) {
		const char *args[] = { editor, real_path(path), NULL };
		struct child_process p = CHILD_PROCESS_INIT;
		int ret, sig;
		static const char *close_notice = NULL;

		if (isatty(2) && !close_notice) {
			char *term = getenv("TERM");

			if (term && strcmp(term, "dumb"))
				/*
				 * go back to the beginning and erase the
				 * entire line if the terminal is capable
				 * to do so, to avoid wasting the vertical
				 * space.
				 */
				close_notice = "\r\033[K";
			else if (term && strstr(term, "emacsclient"))
				/*
				 * `emacsclient` (or `emacsclientw` on Windows) already prints
				 * ("Waiting for Emacs...") if a file is opened for editing.
				 * Therefore, we don't need to print the editor launch info.
				 */
				;
			else
				/* otherwise, complete and waste the line */
				close_notice = _("done.\n");
		}

		if (close_notice) {
			fprintf(stderr, _("Launched editor. Waiting for your input... "));
			fflush(stderr);
		}

		p.argv = args;
		p.env = env;
		p.use_shell = 1;
		if (start_command(&p) < 0)
			return error("unable to start editor '%s'", editor);

		sigchain_push(SIGINT, SIG_IGN);
		sigchain_push(SIGQUIT, SIG_IGN);
		ret = finish_command(&p);
		sig = ret - 128;
		sigchain_pop(SIGINT);
		sigchain_pop(SIGQUIT);

		if (sig == SIGINT || sig == SIGQUIT)
			raise(sig);
		if (ret)
			return error("There was a problem with the editor '%s'.",
					editor);
		if (close_notice)
			fputs(close_notice, stderr);
	}

	if (!buffer)
		return 0;
	if (strbuf_read_file(buffer, path, 0) < 0)
		return error_errno("could not read file '%s'", path);
	return 0;
}
