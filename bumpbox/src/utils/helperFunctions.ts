export const formCloseHandler = (handler: () => void, dirty?: boolean) => {
	if (dirty) {
		const leave = window.confirm(
			'You have unsaved changes. Are you sure you want to leave?'
		);
		if (leave) {
			handler();
		}
	}
	else {
		handler();
	}
};