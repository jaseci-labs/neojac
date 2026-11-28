impl json_ok(data: any) -> Response {
    return Response(body=json.dumps({"ok": True, "data": data}).encode("utf-8"));
}
