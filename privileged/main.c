//
//  main.c
//  privileged
//
//  Created by Bryan Christianson on 13/04/19.
//  Copyright © 2019 Bryan Christianson. All rights reserved.
//
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <https://www.gnu.org/licenses/>.
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
