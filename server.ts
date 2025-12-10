const responseHeaders = {
  "content-type": "application/json; charset=utf-8",
};

type requestParam = {
  fromCurrency: string;
  toCurrency: string;
  value: number;
};

// GET /rate/{fromCurrency}/{toCurrency}
// PUT /rate/{fromCurrency}/{toCurrency}/{value}
// GET /conversion/{fromCurrency}/{toCurrency}/{value}
const router = [
  {
    method: "GET",
    pattern: new RegExp("^/rate/([a-z]{3})/([a-z]{3})$", "i"),
    capture: (m: Array<string>): requestParam => {
      return { fromCurrency: m[1], toCurrency: m[2], value: 0.0 };
    },
    handler: getRate,
  },
  {
    method: "PUT",
    pattern: new RegExp(
      "^/rate/([a-z]{3})/([a-z]{3})/([0-9]*\\.?[0-9]+)$",
      "i",
    ),
    capture: (m: Array<string>): requestParam => {
      return {
        fromCurrency: m[1],
        toCurrency: m[2],
        value: Number.parseFloat(m[3]),
      };
    },
    handler: putRate,
  },
  {
    method: "GET",
    pattern: new RegExp(
      "^/conversion/([a-z]{3})/([a-z]{3})/([0-9]*\\.?[0-9]+)$",
      "i",
    ),
    capture: (m: Array<string>): requestParam => {
      return {
        fromCurrency: m[1],
        toCurrency: m[2],
        value: Number.parseFloat(m[3]),
      };
    },
    handler: getConversion,
  },
];

function getRate(_req: Request, data: requestParam): Response {
  console.log(data);
  return new Response("getRate");
}

function putRate(_req: Request, data: requestParam): Response {
  console.log(data);
  return new Response("putRate");
}

function getConversion(_req: Request, data: requestParam): Response {
  console.log(data);
  return new Response("getConversion");
}

Deno.serve((req) => {
  const url = new URL(req.url);
  for (const { method, pattern, capture, handler } of router) {
    if (method != req.method) {
      continue;
    }
    const match = pattern.exec(url.pathname);
    if (match === null) {
      continue;
    }
    return handler(req, capture(match));
  }
  return new Response(JSON.stringify({ message: "NOT FOUND" }), {
    status: 404,
    headers: responseHeaders,
  });
});
