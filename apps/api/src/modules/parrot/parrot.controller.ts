import { Controller, Post, Body } from "@nestjs/common";

interface EchoResponse {
  parrot: unknown;
  timestamp: string;
}

@Controller("parrot")
export class ParrotController {
  @Post()
  echo(@Body() body: unknown): EchoResponse {
    return {
      parrot: body,
      timestamp: new Date().toISOString(),
    };
  }

  @Post("raw")
  echoRaw(@Body() body: unknown): unknown {
    return body;
  }
}
