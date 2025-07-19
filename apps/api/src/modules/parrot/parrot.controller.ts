import { Controller, Post, Body } from '@nestjs/common';

@Controller('parrot')
export class ParrotController {
  @Post()
  echo(@Body() body: any) {
    return {
      parrot: body,
      timestamp: new Date().toISOString()
    };
  }

  @Post('raw')
  echoRaw(@Body() body: any) {
    return body;
  }
}