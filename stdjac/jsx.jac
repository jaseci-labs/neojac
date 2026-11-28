obj JsxElement {}

type JsxPage = JsxElement;

type JsxLayout = JsxElement;

obj Ref[T] {
    has current: any = None;
}

def new(cls: any, *args: any) -> any;
