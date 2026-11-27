graph layers {
    layer apps { app; }
    layer auth { auth; }
    layer bound { bound; }
    layer byllm { by; }
    layer codec { codec; }
    layer cpython_space { cpython_space; }
    layer crossing { crossing; }
    layer desktop { desktop; }
    layer files { files; }
    layer graphs { graph; }
    layer hosts { hosts; }
    layer jobs { jobs; }
    layer limits { limits; }
    layer llm { llm; }
    layer mail { mail; }
    layer node_space { node_space; }
    layer page_files { page_files; }
    layer plan { plan; }
    layer remote { remote; }
    layer reply { reply; }
    layer routes { routes; }
    layer schedule { schedule; }
    layer static_files { static_files; }
    layer window { window; }
    layer signing { signing | signing_parts; }
    layer signing_pages { pages.*; }
    layer apart { jsx; }
}

graph spaces {
    space signing: browser { entry signing; signing_parts | pages.*; }
}

graph import {
    edge Auth: auth --> apps;
    edge Bound: bound --> apps | auth | files | jobs | limits | llm | mail | remote | schedule;
    edge By: byllm --> llm;
    edge Codec: codec --> bound | byllm | crossing | files | graphs | jobs | plan | remote | routes;
    edge Files: files --> apps | graphs | remote;
    edge Graph: graphs --> apps | auth | remote | routes | schedule;
    edge Hosts: hosts --> apps | cpython_space | desktop | jobs | node_space;
    edge Jobs: jobs --> apps | cpython_space | node_space;
    edge Limits: limits --> apps | auth;
    edge Mail: mail --> auth;
    edge PageFiles: page_files --> crossing;
    edge Plan: plan --> apps | auth | files | jobs | limits | llm | mail | remote | schedule;
    edge Remote: remote --> apps | cpython_space | node_space | routes | schedule;
    edge Reply: reply --> apps | auth | files;
    edge Routes: routes --> apps;
    edge Schedule: schedule --> apps;
    edge StaticFiles: static_files --> apps;
    edge Window: window --> desktop;
    edge Signing: signing --> signing_pages;

    bound ++> app | auth | files | jobs | limits | llm | mail | remote | schedule { bound }
    by ++> llm { By, ByCall, ByChoice, ByChooser, ByStreams, ByTool }
    codec ++> [
        bound { decode },
        by { decode, encode },
        crossing { CodecError, declares_reports, decode, each_held, each_sent, encode },
        files { CodecError, each_held },
        graph { CodecError, decode_object, encode_object, fill_object, shape_of },
        jobs { decode, encode },
        plan { decode },
        remote { CodecError, declares_reports, decode, encode },
        routes { CodecError, decode, encode },
    ]
    plan ++> [
        app {
            Page,
            Window,
            data_dir,
            env_name,
            host,
            keep_arrangement,
            plan,
            remote_url,
            space_code,
            upgrades_made,
        },
        auth { ProgramHost, plan },
        files { ProgramHost, app_data, plan },
        jobs { ProgramHost, plan, space_code },
        limits { host },
        llm { host },
        mail { host },
        remote { host, plan, remote_url },
        schedule { host },
    ]
    files ++> [
        app { asked, files_route, open_files },
        graph { File, files_in, holds_files, sweep_files },
        remote { File, also_held, arrive, takes_files },
    ]
    page_files ++> crossing { File }
    graph ++> [
        app { StoreCodec, Turns, graph_open, held_files, store_in_turn },
        auth { current_caller },
        remote {
            Flight,
            current_caller,
            kept_call,
            stream_begun,
            stream_kept,
            stream_paused,
            stream_resumed,
        },
        routes { kept_call },
        schedule { kept_call },
    ]
    remote ++> [
        app {
            answer_stream,
            carried,
            carry_stream,
            forward_file,
            forward_remote,
            on_loop,
            open_stream,
            pull_stream,
            refused,
            transport,
        },
        cpython_space { carry_in_process },
        node_space { carry_in_process, loop_serving, on_loop },
        routes {
            Endpoint,
            answer,
            endpoint_named,
            json_values,
            raised_at,
            refuse_unknown,
            refused,
            reply_fail,
        },
        schedule { settle },
    ]
    auth ++> app { auth_caller, auth_route, deployment_signed, open_auth }
    hosts ++> [
        app { space_host, window_host },
        cpython_space { SpaceHost, register_space_host },
        desktop { WindowHost, register_window_host },
        jobs { space_host },
        node_space { SpaceHost, register_space_host },
    ]
    jobs ++> [
        app { ran_job },
        cpython_space { register_hosted_jobs },
        node_space { register_hosted_jobs },
    ]
    limits ++> [
        app { limited, limited_files },
        auth { consume_limit },
    ]
    mail ++> auth { mailer }
    reply ++> app | auth | files { json_ok }
    routes ++> app { route_answer, route_of, routes }
    schedule ++> app { scheduled, start_schedule }
    static_files ++> app { held_file, static_file }
    window ++> desktop { run_window }
    signing_parts ++> [
        pages.check { Said, again_on_new_link, mailed_token, reason },
        pages.device { Said, reason },
        pages.index { reason },
        pages.reset { Said, again_on_new_link, mailed_token, reason },
    ]
}
