import cf from 'cloudfront';

const kvs = cf.kvs();

async function handler(event) {
    const request = event.request;
    let variant = request.cookies['x-sp-ab'] && request.cookies['x-sp-ab'].value;
    if (variant !== 'a' && variant !== 'b') {
        const weight = Number(await kvs.get('weight'));
        variant = Math.random() < weight ? 'b' : 'a';
        request.headers['x-sp-new-visitor'] = { value: variant };
    }
    request.cookies['x-sp-ab'] = { value: variant };
    request.uri = await kvs.get('version_' + variant);
    return request;
}
