/*---------------------------------------------------------------------------------------------
 *  Copyright (c) StackCodeSy. All rights reserved.
 *  Licensed under the MIT License.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';

interface StackCodeSySession {
	id: string;
	accessToken: string;
	account: {
		label: string;
		id: string;
	};
	scopes: string[];
}

interface StackCodeSyUserInfo {
	userId: string;
	userName: string;
	userEmail: string;
	token: string;
}

/**
 * StackCodeSy Authentication Provider
 *
 * This provider integrates with your platform's authentication system.
 * It reads user information from environment variables or API endpoints.
 */
class StackCodeSyAuthenticationProvider implements vscode.AuthenticationProvider {
	private _sessionChangeEmitter = new vscode.EventEmitter<vscode.AuthenticationProviderAuthenticationSessionsChangeEvent>();
	private _sessions: StackCodeSySession[] = [];

	get onDidChangeSessions(): vscode.Event<vscode.AuthenticationProviderAuthenticationSessionsChangeEvent> {
		return this._sessionChangeEmitter.event;
	}

	/**
	 * Get current sessions
	 * Checks environment variables or queries your authentication API
	 */
	async getSessions(scopes?: readonly string[]): Promise<readonly vscode.AuthenticationSession[]> {
		// Try to get user info from environment variables (passed from your platform)
		const userInfo = this.getUserInfoFromEnvironment();

		if (userInfo) {
			// Create or update session
			const session = this.createSessionFromUserInfo(userInfo);
			this._sessions = [session];
			return this._sessions;
		}

		// Try to get from API endpoint (if you expose one)
		const apiUserInfo = await this.getUserInfoFromAPI();
		if (apiUserInfo) {
			const session = this.createSessionFromUserInfo(apiUserInfo);
			this._sessions = [session];
			return this._sessions;
		}

		return [];
	}

	/**
	 * Create a new session (login)
	 * This is called when the user is not authenticated
	 */
	async createSession(scopes: readonly string[]): Promise<vscode.AuthenticationSession> {
		// In a web environment, you would redirect to your login page
		// For now, we return an error that prompts authentication
		throw new Error('Please authenticate through the StackCodeSy platform before accessing the editor.');
	}

	/**
	 * Remove a session (logout)
	 */
	async removeSession(sessionId: string): Promise<void> {
		const sessionIndex = this._sessions.findIndex(s => s.id === sessionId);
		if (sessionIndex > -1) {
			this._sessions.splice(sessionIndex, 1);
			this._sessionChangeEmitter.fire({
				added: [],
				removed: [{ id: sessionId } as vscode.AuthenticationSession],
				changed: []
			});
		}
	}

	/**
	 * Read user information from environment variables
	 * Your platform should inject these when launching the editor
	 */
	private getUserInfoFromEnvironment(): StackCodeSyUserInfo | null {
		const userId = process.env.STACKCODESY_USER_ID;
		const userName = process.env.STACKCODESY_USER_NAME;
		const userEmail = process.env.STACKCODESY_USER_EMAIL;
		const token = process.env.STACKCODESY_AUTH_TOKEN;

		if (userId && userName && userEmail && token) {
			return { userId, userName, userEmail, token };
		}

		return null;
	}

	/**
	 * Query your authentication API endpoint
	 * This endpoint should validate the connection token and return user info
	 */
	private async getUserInfoFromAPI(): Promise<StackCodeSyUserInfo | null> {
		try {
			// Get the API endpoint from environment
			const authApiUrl = process.env.STACKCODESY_AUTH_API;
			if (!authApiUrl) {
				return null;
			}

			// Make request to your auth API
			// The API should validate cookies/sessions from your platform
			const response = await fetch(authApiUrl, {
				credentials: 'include', // Include cookies
				headers: {
					'Accept': 'application/json'
				}
			});

			if (!response.ok) {
				return null;
			}

			const data = await response.json();

			// Expected response format from your API:
			// {
			//   "userId": "123",
			//   "userName": "John Doe",
			//   "userEmail": "john@example.com",
			//   "token": "your-secure-token"
			// }
			return {
				userId: data.userId,
				userName: data.userName,
				userEmail: data.userEmail,
				token: data.token
			};
		} catch (error) {
			console.error('Failed to get user info from API:', error);
			return null;
		}
	}

	/**
	 * Create a session object from user info
	 */
	private createSessionFromUserInfo(userInfo: StackCodeSyUserInfo): StackCodeSySession {
		return {
			id: userInfo.userId,
			accessToken: userInfo.token,
			account: {
				label: `${userInfo.userName} (${userInfo.userEmail})`,
				id: userInfo.userId
			},
			scopes: ['user:read', 'user:email']
		};
	}
}

export function activate(context: vscode.ExtensionContext) {
	console.log('StackCodeSy Authentication Provider is now active');

	const provider = new StackCodeSyAuthenticationProvider();

	context.subscriptions.push(
		vscode.authentication.registerAuthenticationProvider(
			'stackcodesy',
			'StackCodeSy',
			provider,
			{ supportsMultipleAccounts: false }
		)
	);

	// Auto-authenticate on startup if user info is available
	provider.getSessions().then(sessions => {
		if (sessions.length > 0) {
			console.log('StackCodeSy: User authenticated -', sessions[0].account.label);
		}
	});
}

export function deactivate() {
	console.log('StackCodeSy Authentication Provider is now deactivated');
}
