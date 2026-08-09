function handler(event) {
  var response = event.response;
  var request = event.request;
  var type = request.querystring && request.querystring.type ? request.querystring.type.value : ((request.headers['x-device-type'] || {}).value || 'desktop');
  response.headers['x-device-type'] = {value:type};
  response.headers['x-resized'] = {value:'true'};
  return response;
}
