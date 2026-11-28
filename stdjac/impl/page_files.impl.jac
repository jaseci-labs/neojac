impl File.init(source: any, ctype: str = "") {
    file_local(self, source, ctype);
}

impl File.read -> bytes {
    data: bytes = await file_bytes(self);
    return data;
}

impl File.url -> str {
    where: str = file_address(self);
    return where;
}
