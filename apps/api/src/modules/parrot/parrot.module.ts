import { Module } from "@nestjs/common";
import { ParrotController } from "./parrot.controller";

@Module({
  controllers: [ParrotController],
})
export class ParrotModule {}
