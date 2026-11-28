import from jaclang.comptime {
    fields,
    kind,
    type_args,
    members,
    get_field,
    set_field,
    restore,
    sendable,
    holds,
    nullable,
    Kind,
}

obj CodecError(Exception) {
    has detail: str,
        path: str = "";

    def __str__ -> str;
}

def encode[T](v: T) -> any;
def encode_sent[T](v: T) -> any;
def decode[T](v: any) -> T;
def decode_sent[T](v: any) -> T;
def decode_bytes[T](v: any) -> T;
def decode_wide[T](v: any) -> T;
def encode_items[T](v: T) -> list[any];
def encode_tuple[T](v: T) -> list[any];
def encode_dict[T](v: T) -> any;
def written_as[T] -> str;
def shape_of[T] -> str;
def fill_object[T](into: T, v: any);
def encode_object[T](v: T) -> any;
def encode_struct[T](v: T) -> dict[str, any];
def encode_array[T](v: T) -> list[any];
def decode_complex(v: any) -> complex;
def decode_array[T](v: any) -> T;
def decode_items[T](v: any) -> T;
def decode_tuple[T](v: any) -> T;
comptime def variadic(t: any) -> bool;
def decode_dict[T](v: any) -> T;
def decode_object[T](v: any) -> T;
def decode_struct[T](v: any) -> T;
def encode_kept[T](v: T) -> any;
def decode_kept[T](v: any) -> T;
def declares_reports[W] -> bool;
def each_held[T, F](v: T, found: Callable[[F], None]);
def each_sent[T, F](v: T, sent: any, found: Callable[[F, dict[str, any]], None]);
