def filter(event)
    kv = event.get('kv')
    event_data = event.get('event_data')
    (1..kv.length/2).to_a.each do |i|
        if kv.has_key?("cs#{i}Label") 
            key = kv.delete("cs#{i}Label")
            event_data[key] = kv.delete("cs#{i}")
        end
    end

    kv.each do |k,v|
        event_data[k] = v
    end

    event.set("event_data", event_data)

    return [event]
end

test "Basic test" do
    in_event { 
        {
            "event_data" => {
                "component" => "cloud_controller_ng",
                "api_version" => "2.142.0",
                "severity" => "0"
            },
            "kv" => {
                "rt" => "1586666442040",
                "cs1Label" => "userAuthenticationMechanism",
                "cs5" => "10.8.4.7",
                "cs1" => "no-auth",
                "dst" => "10.8.4.7",
                "cs4" => "200",
                "cs2Label" => "vcapRequestId",
                "cs3Label" => "result",
                "suser" => "suid=",
                "cs5Label" => "xForwardedFor",
                "cs3" => "success",
                "request" => "/internal/v4/syslog_drain_urls?batch_size\\=1000&next_id\\=0",
                "requestMethod" => "GET",
                "src" => "10.8.4.7",
                "cs2" => "b787dd68-6aaa-410d-934f-c95b77b15682",
                "cs4Label" => "httpStatusCode"
            }
        }
    }

    expect("event_data is populated") do |events|
        events.size == 1
        event = events[0]

        event.get('event_data').size == 14
        event.get('event_data').each do |k,v|
            !k.start_with?("cs")
        end
    end
end