import from "@jac/runtime/core" { file_address, file_bytes, file_local }

glob OCTETS: str = "application/octet-stream";

obj File {
    has id: str = "",
        size: int = 0,
        ctype: str = OCTETS;

    def init(source: any, ctype: str = "");
    async def read -> bytes;
    def url -> str;
}
