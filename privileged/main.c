//
//  main.c
//  privileged
//
//  Created by Bryan Christianson on 13/04/19.
//  Copyright © 2019 Bryan Christianson. All rights reserved.
//

#include <stdio.h>
#include "privileged.h"

int main(int argc, const char *argv[]) {
	const char *prompt;
	AuthorizationRef auth = NULL;
	int ret = 1;
	int i;
	int nargs = 0;
	const char *args[32];
	const char *cmd;

	if (argc == 1) {
		ret = 0;
		goto EXIT;
	}

	prompt = getenv("AUTH_PROMPT");
	auth = authorise(prompt);
	if (auth == NULL) {
		fprintf(stderr, "Authorisation failed!!.");
		goto EXIT;
	}

	cmd = argv[1];
	nargs = 0;
	for(i = 1; i < argc; ++i) {
		args[nargs++] = argv[i];
	}
	args[nargs] = NULL;

	printf("\n");
	for(i = 0; i < nargs; ++i) {
		printf(" %s", args[i]);
	}
	printf("\n");

	ret = AuthorizedCommand(auth, cmd, args);
	if (ret != 0) { ret = 1; }

EXIT:
	if (auth != NULL) {
		AuthorizationFree(auth, kAuthorizationFlagDefaults);
	}
	return ret;
}
