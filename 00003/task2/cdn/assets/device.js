function handler(event) {
  var request = event.request;
  if (Object.keys(request.querystring || {}).length !== 0) return request;
  var ua = request.headers['user-agent'] ? request.headers['user-agent'].value : '';
  var mobileHeader = request.headers['cloudfront-is-mobile-viewer'];
  var mobile = (mobileHeader && mobileHeader.value === 'true') || /Mobile|Android|iPhone/i.test(ua);
  var type = mobile ? 'mobile' : 'desktop';
  request.querystring = mobile ? {w:{value:'480'},h:{value:'320'},type:{value:type}} : {w:{value:'1920'},h:{value:'1080'},type:{value:type}};
  request.headers['x-device-type'] = {value:type};
  return request;
}
