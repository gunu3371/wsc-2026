function handler(event) {
    const response = event.response;
    const assigned = event.request.headers['x-sp-new-visitor'];
    if (assigned) {
        response.cookies['x-sp-ab'] = {
            value: assigned.value,
            attributes: 'Path=/; Max-Age=86400; Secure; SameSite=Lax'
        };
    }
    return response;
}
