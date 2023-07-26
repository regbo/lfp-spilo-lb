$namespace = "tcp_dynamic_upstream"
$route_list_cache_key = "route_list"
$route_list_load_time_cache_key = "route_list_load_time"

$mutex = Mutex.new :global => true
$cache = Cache.new :namespace => $namespace, :size_mb => 1

def get_route (locked = false)
  route_list = get_route_list
  if route_list == nil
    if !locked
      $mutex.lock
      begin
        return get_route true
      ensure
        $mutex.unlock
      end
    else
      route_list = load_route_list
    end
  end
  if route_list.length == 0
    nil
  else
    route_list.length == 1 ? route_list[0] : route_list.sample
  end
end

def get_route_list
  route_list = $cache[$route_list_cache_key]&.split(",")
  if route_list == nil
    return nil
  end
  route_list_load_time = $cache[$route_list_load_time_cache_key]
  if route_list_load_time == nil
    return nil
  end
  route_list_load_time_elapsed = ((Time.now.to_f * 1000).to_i - route_list_load_time.to_i)
  if route_list_load_time_elapsed > ENV["NGINX_UPSTREAM_HTTP_SERVER_CACHE_TTL"].to_i
    return nil
  end
  Nginx::Stream.log Nginx::Stream::LOG_DEBUG, ("ROUTE_LIST_CACHED:" + route_list.to_s)
  route_list
end

def load_route_list
  request = ENV["NGINX_UPSTREAM_HTTP_SERVER"]
  Nginx::Stream.log Nginx::Stream::LOG_DEBUG, ("ROUTE_LIST_LOADING:" + request)
  parser = HTTP::Parser.new()
  request_url = parser.parse_url(request)
  response = SimpleHttp.new(request_url.schema, request_url.host, request_url.port).request("GET", request_url.path, {
    "User-Agent" => $namespace
  })
  body = response.body
  Nginx::Stream.log Nginx::Stream::LOG_DEBUG, ("RESPONSE_BODY:" + body)
  data = JSON::parse(body)
  route_list = Array.new
  members = data["members"]
  if members
    for member in members do
      state = member["role"]
      if state && state.casecmp?("leader")
        route_list << (member["name"] + ":" + member["port"].to_s)
      end
    end
  end
  $cache[$route_list_cache_key] = route_list.join(",")
  $cache[$route_list_load_time_cache_key] = (Time.now.to_f * 1000).to_s
  route_list
end

retry_count = 5
time_slice = 1 # sec
begin
  started = Time.now
  route = get_route
  if route != nil
    Nginx::Stream.log Nginx::Stream::LOG_DEBUG, ("ROUTE: " + route)
    connection = Nginx::Stream::Connection.new ENV["NGINX_UPSTREAM_DYNAMIC_SERVER"]
    connection.upstream_server = route
  else
    raise Exception.new "Route not found"
  end
rescue Exception => e
  retry_count -= 1
  if retry_count > 0
    Nginx::Stream.log Nginx::Stream::LOG_WARN, e
    sleep [time_slice - (Time.now - started), 0].max
    retry
  else
    Nginx::Stream.log Nginx::Stream::LOG_ERR, e
  end
end